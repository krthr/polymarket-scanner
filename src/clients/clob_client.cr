require "json"
require "uri"
require "./api_models"
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
          page = APIModels::ClobSamplingResponse.from_json(@http.get(path))
          markets.concat(page.to_domain_markets.first(max_markets - markets.size))

          cursor = page.next_cursor
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
        APIModels::ClobBook.from_json(body).to_domain
      end

      def self.parse_sampling_markets(body : String) : Array(Market)
        root = JSON.parse(body)
        if root.as_a?
          Array(APIModels::ClobSamplingMarket).from_json(body).compact_map(&.to_domain)
        else
          APIModels::ClobSamplingResponse.from_json(body).to_domain_markets
        end
      end

      def self.parse_sampling_markets(root : JSON::Any) : Array(Market)
        parse_sampling_markets(root.to_json)
      end
    end
  end
end
