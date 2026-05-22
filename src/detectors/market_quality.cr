require "./context"

module PolyScan
  module Detectors
    class SpreadAnomalyDetector
      def scan(ctx : Context) : ScanResult
        result = ScanResult.new
        ctx.books.all.each do |book|
          spread = book.spread
          next unless spread
          next unless spread >= ctx.config.max_spread
          next unless book.ask_depth >= ctx.config.min_depth

          result.signals << Signal.new(
            id: "spread-#{book.token_id}",
            detector: "SpreadAnomaly",
            market_id: book.market_id,
            token_ids: [book.token_id],
            status: SignalStatus::Observe,
            edge_net: spread,
            score: spread,
            confidence: Fixed.parse("0.500000"),
            risk_flags: [RiskFlags::WIDE_SPREAD],
            rationale: "Book has a wide top-of-book spread while still showing configured minimum ask depth."
          )
        end
        result
      end
    end

    class StalePriceDetector
      def scan(ctx : Context) : ScanResult
        result = ScanResult.new
        ctx.books.all.each do |book|
          next unless ctx.book_stale?(book)
          result.signals << Signal.new(
            id: "stale-#{book.token_id}",
            detector: "StalePrice",
            market_id: book.market_id,
            token_ids: [book.token_id],
            status: SignalStatus::Observe,
            edge_net: Fixed.zero,
            score: Fixed.zero,
            confidence: Fixed.parse("0.250000"),
            risk_flags: [RiskFlags::STALE_BOOK],
            rationale: "Book age exceeds configured freshness limit. Reconnect/resync should refresh before acting."
          )
        end
        result
      end
    end

    class BookImbalanceDetector
      def scan(ctx : Context) : ScanResult
        result = ScanResult.new
        ctx.books.all.each do |book|
          bid_depth = top_depth(book.bids)
          ask_depth = top_depth(book.asks)
          next unless bid_depth.positive? && ask_depth.positive?

          larger = bid_depth > ask_depth ? bid_depth : ask_depth
          smaller = bid_depth > ask_depth ? ask_depth : bid_depth
          ratio = larger / smaller
          next unless ratio >= ctx.config.imbalance_ratio

          result.signals << Signal.new(
            id: "imbalance-#{book.token_id}",
            detector: "BookImbalance",
            market_id: book.market_id,
            token_ids: [book.token_id],
            status: SignalStatus::Observe,
            edge_net: Fixed.zero,
            score: ratio,
            confidence: Fixed.parse("0.400000"),
            risk_flags: [] of String,
            rationale: "Top levels show one-sided depth imbalance. This is supporting context only, not a standalone opportunity."
          )
        end
        result
      end

      private def top_depth(levels : Array(BookLevel)) : Fixed
        levels.first(3).reduce(Fixed.zero) { |sum, level| sum + level.size }
      end
    end
  end
end
