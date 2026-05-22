require "json"
require "./http_client"
require "../domain/models"

module PolyScan
  module Clients
    class ClobClient
      def initialize(@http : HttpClient)
      end

      def fetch_book(token_id : String) : OrderBook
        self.class.parse_book(@http.get("/book?token_id=#{token_id}"))
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
        market_id = optional_string(node, "market_id")
        outcome_name = optional_string(node, "outcome_name")
        fetched_at = int64(node, "fetched_at_unix_ms", Time.utc.to_unix_ms)
        sequence = int64(node, "sequence", 0_i64)
        bids = parse_levels(node["bids"]?)
        asks = parse_levels(node["asks"]?)
        OrderBook.new(token_id, market_id, outcome_name, bids, asks, fetched_at, sequence)
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
        node[key]?.try(&.as_i64) || default
      end
    end
  end
end
