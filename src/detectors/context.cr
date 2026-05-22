require "../app/config"
require "../domain/models"
require "../domain/order_book_cache"
require "../domain/relationships"
require "../engine/fees"
require "../engine/scorer"
require "../engine/vwap"

module PolyScan
  module Detectors
    class Context
      getter config : App::Config
      getter markets : Array(Market)
      getter books : OrderBookCache
      getter graph : RelationshipGraph
      getter fee_engine : Engine::TakerFeeEngine

      def initialize(@config : App::Config, @markets : Array(Market), @books : OrderBookCache, @graph : RelationshipGraph)
        @fee_engine = Engine::TakerFeeEngine.new(@config.taker_fee_bps)
      end

      def all_outcomes : Array(Outcome)
        @markets.flat_map(&.outcomes)
      end

      def outcome_by_yes_token(token_id : String) : Outcome?
        all_outcomes.find { |outcome| outcome.yes_token_id == token_id }
      end

      def outcome_by_any_token(token_id : String) : Outcome?
        all_outcomes.find { |outcome| outcome.yes_token_id == token_id || outcome.no_token_id == token_id }
      end

      def no_token_for_yes(yes_token_id : String) : String?
        outcome_by_yes_token(yes_token_id).try(&.no_token_id)
      end

      def market_for_outcome(outcome : Outcome) : Market?
        @markets.find { |market| market.id == outcome.market_id }
      end

      def book_stale?(book : OrderBook) : Bool
        book.stale?(@config.max_book_age_ms)
      end
    end

    class ScanResult
      getter opportunities : Array(Opportunity)
      getter signals : Array(Signal)

      def initialize(@opportunities = [] of Opportunity, @signals = [] of Signal)
      end

      def add(other : ScanResult) : Nil
        @opportunities.concat(other.opportunities)
        @signals.concat(other.signals)
      end
    end
  end
end
