require "json"
require "log"
require "../clients/clob_client"
require "../clients/gamma_client"
require "../domain/models"
require "../domain/order_book_cache"
require "./config"

module PolyScan
  module App
    module GammaMarketSource
      abstract def fetch_market_events(max_markets : Int32) : Array(Event)
    end

    module ClobBookSource
      abstract def fetch_book(token_id : String) : OrderBook
    end

    class ListingSkip
      include JSON::Serializable

      getter market_id : String?
      getter slug : String?
      getter token_id : String?
      getter reason : String

      def initialize(@market_id : String?, @slug : String?, @reason : String, @token_id : String? = nil)
      end
    end

    class MarketDataResult
      getter events : Array(Event)
      getter markets : Array(Market)
      getter books : OrderBookCache
      getter skipped_listings : Array(ListingSkip)

      def initialize(@events : Array(Event), @markets : Array(Market), @books : OrderBookCache, @skipped_listings = [] of ListingSkip)
      end
    end

    abstract class MarketDataProvider
      abstract def load : MarketDataResult
    end

    class RealPolymarketProvider < MarketDataProvider
      def initialize(@config : Config, @gamma_client : GammaMarketSource, @clob_client : ClobBookSource)
      end

      def load : MarketDataResult
        source_events = @gamma_client.fetch_market_events(@config.market_limit)
        skipped = [] of ListingSkip
        eligible_events = filter_events(source_events, skipped)
        eligible_markets = eligible_events.flat_map(&.markets)
        books = fetch_books(eligible_markets, skipped)

        MarketDataResult.new(eligible_events, eligible_markets, books, skipped)
      end

      def self.token_ids(market : Market) : Array(String)
        market.outcomes.flat_map do |outcome|
          ids = [outcome.yes_token_id]
          if no_token_id = outcome.no_token_id
            ids << no_token_id
          end
          ids
        end.uniq
      end

      def self.ineligible_reason(market : Market) : String?
        return "inactive" unless market.active
        return "closed" if market.closed
        return "archived" if market.archived
        return "not_accepting_orders" unless market.accepting_orders
        return "missing_clob_tokens" if token_ids(market).empty?
        nil
      end

      private def filter_events(events : Array(Event), skipped : Array(ListingSkip)) : Array(Event)
        events.compact_map do |event|
          filtered = Event.new(event.id, event.slug, event.title, event.category)

          event.markets.each do |market|
            if reason = self.class.ineligible_reason(market)
              skip = ListingSkip.new(market.id, market.slug, reason)
              skipped << skip
              log_skip(skip)
            else
              filtered.markets << market
            end
          end

          filtered.markets.empty? ? nil : filtered
        end
      end

      private def fetch_books(markets : Array(Market), skipped : Array(ListingSkip)) : OrderBookCache
        books = OrderBookCache.new
        token_market = {} of String => Market

        markets.each do |market|
          self.class.token_ids(market).each do |token_id|
            token_market[token_id] ||= market
          end
        end

        token_market.keys.first(@config.book_limit).each do |token_id|
          market = token_market[token_id]
          begin
            book = @clob_client.fetch_book(token_id)
            errors = book.validation_errors
            unless errors.empty?
              skip = ListingSkip.new(market.id, market.slug, "invalid_book: #{errors.join(", ")}", token_id)
              skipped << skip
              log_skip(skip)
              next
            end

            books.put(book)
          rescue ex
            skip = ListingSkip.new(market.id, market.slug, "book_fetch_failed: #{ex.message}", token_id)
            skipped << skip
            log_skip(skip)
          end
        end

        books
      end

      private def log_skip(skip : ListingSkip) : Nil
        Log.warn do
          JSON.build do |json|
            json.object do
              json.field "event", "listing_skipped"
              json.field "market_id", skip.market_id
              json.field "slug", skip.slug
              json.field "token_id", skip.token_id if skip.token_id
              json.field "reason", skip.reason
            end
          end
        end
      end
    end

    class FixtureMarketDataProvider < MarketDataProvider
      def initialize(@gamma_fixture_path : String, @clob_books_path : String)
      end

      def load : MarketDataResult
        events = Clients::GammaClient.events_from_file(@gamma_fixture_path)
        markets = events.flat_map(&.markets)
        books = OrderBookCache.new
        Clients::ClobClient.books_from_dir(@clob_books_path).each { |book| books.put(book) }
        MarketDataResult.new(events, markets, books)
      end
    end
  end

  module Clients
    class GammaClient
      include App::GammaMarketSource
    end

    class ClobClient
      include App::ClobBookSource
    end
  end
end
