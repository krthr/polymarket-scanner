require "json"
require "uri"
require "./http_client"
require "../domain/models"

module PolyScan
  module Clients
    class ClobClient
      def initialize(@http : HttpClient)
      end

      def fetch_book(token_id : String) : OrderBook
        self.class.parse_book(@http.get("/book?token_id=#{URI.encode_path_segment(token_id)}"))
      end

      def fetch_sampling_markets(max_markets : Int32) : Array(Market)
        markets = [] of Market
        cursor : String? = nil

        while markets.size < max_markets
          path = cursor ? "/sampling-markets?next_cursor=#{URI.encode_path_segment(cursor.not_nil!)}" : "/sampling-markets"
          page = JSON.parse(@http.get(path))
          markets.concat(self.class.parse_sampling_markets(page).first(max_markets - markets.size))

          cursor = page["next_cursor"]?.try(&.as_s?)
          break if cursor.nil? || cursor == "LTE=" || cursor == ""
        end

        markets
      end

      def self.book_from_file(path : String) : OrderBook
        parse_book(File.read(path))
      end

      def self.books_from_dir(path : String) : Array(OrderBook)
        return [] of OrderBook unless Dir.exists?(path)
        Dir.glob(File.join(path, "*.json")).sort.map { |file| book_from_file(file) }
      end

      def self.parse_book(body : String) : OrderBook
        node = JSON.parse(body)
        token_id = string(node, "token_id", string(node, "asset_id", "token-unknown"))
        market_id = optional_string(node, "market_id") || optional_string(node, "market")
        outcome_name = optional_string(node, "outcome_name")
        fetched_at = timestamp_ms(node)
        sequence = int64(node, "sequence", 0_i64)
        bids = parse_levels(node["bids"]?)
        asks = parse_levels(node["asks"]?)
        OrderBook.new(token_id, market_id, outcome_name, bids, asks, fetched_at, sequence)
      end

      def self.parse_sampling_markets(root : JSON::Any) : Array(Market)
        nodes = root["data"]?.try(&.as_a) || root.as_a? || [] of JSON::Any
        nodes.compact_map { |node| parse_sampling_market(node) }
      end

      private def self.parse_sampling_market(node : JSON::Any) : Market?
        return nil unless bool(node, "active", false)
        return nil if bool(node, "closed", false)
        return nil if bool(node, "archived", false)
        return nil unless bool(node, "enable_order_book", true)

        market_id = optional_string(node, "condition_id") || optional_string(node, "question_id") || optional_string(node, "market_slug")
        return nil unless market_id

        slug = optional_string(node, "market_slug") || market_id
        question = optional_string(node, "question") || slug
        end_time = optional_string(node, "end_date_iso")
        market = Market.new(market_id, "clob-live", slug, question, "live", end_time, true)

        tokens = node["tokens"]?.try(&.as_a) || [] of JSON::Any
        market.outcomes = outcomes_from_tokens(market, tokens)
        return nil if market.outcomes.empty?
        market
      end

      private def self.outcomes_from_tokens(market : Market, tokens : Array(JSON::Any)) : Array(Outcome)
        yes_token = tokens.find { |token| optional_string(token, "outcome").try(&.downcase) == "yes" }
        no_token = tokens.find { |token| optional_string(token, "outcome").try(&.downcase) == "no" }

        if yes_token && no_token
          return [
            Outcome.new(
              market.id,
              market.id,
              market.question,
              string(yes_token, "token_id", "missing-yes-token"),
              string(no_token, "token_id", "missing-no-token"),
              nil,
              Fixed.parse("0.500000")
            ),
          ]
        end

        tokens.compact_map do |token|
          token_id = optional_string(token, "token_id")
          outcome_name = optional_string(token, "outcome")
          next unless token_id && outcome_name

          Outcome.new(
            "#{market.id}-#{outcome_name}",
            market.id,
            outcome_name,
            token_id,
            nil,
            nil,
            Fixed.parse("0.500000")
          )
        end
      end

      private def self.parse_levels(node : JSON::Any?) : Array(BookLevel)
        return [] of BookLevel unless node
        node.as_a.map do |level|
          BookLevel.new(
            Fixed.parse(decimal_string(level, "price")),
            Fixed.parse(decimal_string(level, "size"))
          )
        end
      end

      private def self.decimal_string(node : JSON::Any, key : String) : String
        value = node[key]? || raise ArgumentError.new("book level missing #{key}")
        str = value.as_s?
        raise ArgumentError.new("book level #{key} must be a string fixed-point decimal") unless str
        str
      end

      private def self.string(node : JSON::Any, key : String, default : String) : String
        optional_string(node, key) || default
      end

      private def self.optional_string(node : JSON::Any, key : String) : String?
        node[key]?.try { |value| value.as_s? || value.to_json }
      end

      private def self.int64(node : JSON::Any, key : String, default : Int64) : Int64
        value = node[key]?
        return default unless value
        value.as_i64? || value.as_s?.try(&.to_i64?) || default
      end

      private def self.bool(node : JSON::Any, key : String, default : Bool) : Bool
        value = node[key]?
        value ? value.as_bool : default
      end

      private def self.timestamp_ms(node : JSON::Any) : Int64
        explicit = int64(node, "fetched_at_unix_ms", 0_i64)
        return explicit if explicit > 0

        raw = int64(node, "timestamp", 0_i64)
        return Time.utc.to_unix_ms if raw <= 0
        raw < 10_000_000_000_i64 ? raw * 1000 : raw
      end
    end
  end
end
