require "./context"

module PolyScan
  module Detectors
    class ModelEdgeDetector
      def scan(ctx : Context) : ScanResult
        result = ScanResult.new

        ctx.all_outcomes.each do |outcome|
          p_hat = outcome.p_hat
          next unless p_hat

          risk_flags = [] of String
          book = ctx.books.get(outcome.yes_token_id)
          unless book
            risk_flags << RiskFlags::LOW_DEPTH
            next
          end

          fill = Engine::VWAPEngine.buy(book, ctx.config.scan_size)
          next unless fill.full_fill

          fee = ctx.fee_engine.fee_for_fill(fill)
          gross_edge = p_hat - fill.notional
          risk_flags << RiskFlags::STALE_BOOK if ctx.book_stale?(book)
          risk_flags << RiskFlags::LOW_CONFIDENCE if outcome.confidence < ctx.config.low_confidence_threshold
          risk_flags << RiskFlags::STALE_EXTERNAL_SOURCE if outcome.external_source_stale

          stale_penalty = risk_flags.includes?(RiskFlags::STALE_BOOK) ? ctx.config.stale_book_penalty : Fixed.zero
          freshness = risk_flags.includes?(RiskFlags::STALE_BOOK) ? Fixed.parse("0.500000") : Fixed.one
          breakdown = Engine::Scorer.score(
            gross_edge: gross_edge,
            fees: fee,
            slippage_buffer: ctx.config.slippage_buffer,
            uncertainty_penalty: ctx.config.uncertainty_penalty,
            resolution_penalty: ctx.config.resolution_penalty,
            stale_book_penalty: stale_penalty,
            confidence_factor: outcome.confidence,
            liquidity_factor: Fixed.one,
            freshness_factor: freshness,
            rule_quality_factor: Fixed.one
          )

          next unless breakdown.edge_net.positive?

          result.signals << Signal.new(
            id: "model-edge-#{outcome.yes_token_id}",
            detector: "ModelEdge",
            market_id: outcome.market_id,
            token_ids: [outcome.yes_token_id],
            status: breakdown.status,
            edge_net: breakdown.edge_net,
            score: breakdown.score,
            confidence: outcome.confidence,
            risk_flags: risk_flags.uniq,
            rationale: "Manual p_hat exceeds executable YES VWAP after taker fee and configured penalties."
          )
        end

        result
      end
    end
  end
end
