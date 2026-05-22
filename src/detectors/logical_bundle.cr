require "./context"

module PolyScan
  module Detectors
    abstract class LogicalBundleDetector
      protected def build_buy_leg(ctx : Context, token_id : String, label : String, action : String, risk_flags : Array(String)) : OpportunityLeg?
        book = ctx.books.get(token_id)
        unless book
          risk_flags << RiskFlags::LOW_DEPTH
          return nil
        end

        errors = book.validation_errors
        unless errors.empty?
          risk_flags << RiskFlags::LOW_DEPTH
          return nil
        end

        fill = Engine::VWAPEngine.buy(book, ctx.config.scan_size)
        unless fill.full_fill
          risk_flags << RiskFlags::LOW_DEPTH
          return nil
        end

        risk_flags << RiskFlags::STALE_BOOK if ctx.book_stale?(book)
        if spread = book.spread
          risk_flags << RiskFlags::WIDE_SPREAD if spread >= ctx.config.max_spread
        end

        fee = ctx.fee_engine.fee_for_fill(fill)
        risk_flags << RiskFlags::HIGH_FEES if fee >= ctx.config.high_fee_threshold
        OpportunityLeg.new(action, token_id, label, ctx.config.scan_size, fill.average_price, fill.notional, fee)
      end

      protected def finalize_opportunity(ctx : Context, detector : String, rule : RelationshipRule, legs : Array(OpportunityLeg), risk_flags : Array(String), rationale : String) : Opportunity?
        return nil if legs.empty?

        notional = legs.reduce(Fixed.zero) { |sum, leg| sum + leg.notional }
        fees = legs.reduce(Fixed.zero) { |sum, leg| sum + leg.fee }
        gross_edge = Fixed.one - notional
        stale_penalty = risk_flags.includes?(RiskFlags::STALE_BOOK) ? ctx.config.stale_book_penalty : Fixed.zero
        freshness = risk_flags.includes?(RiskFlags::STALE_BOOK) ? Fixed.parse("0.500000") : Fixed.one

        risk_flags << RiskFlags::LOW_CONFIDENCE if rule.confidence < ctx.config.low_confidence_threshold
        risk_flags.uniq!

        breakdown = Engine::Scorer.score(
          gross_edge: gross_edge,
          fees: fees,
          slippage_buffer: ctx.config.slippage_buffer,
          uncertainty_penalty: ctx.config.uncertainty_penalty,
          resolution_penalty: ctx.config.resolution_penalty,
          stale_book_penalty: stale_penalty,
          confidence_factor: rule.confidence,
          liquidity_factor: Fixed.one,
          freshness_factor: freshness,
          rule_quality_factor: rule.quality
        )

        return nil unless breakdown.edge_net.positive?

        id = "#{detector.downcase}-#{rule.id}"
        Opportunity.new(
          id: id,
          detector: detector,
          rule_id: rule.id,
          status: breakdown.status,
          gross_edge: breakdown.gross_edge,
          fees: breakdown.fees,
          edge_net: breakdown.edge_net,
          score: breakdown.score,
          confidence: rule.confidence,
          risk_flags: risk_flags,
          legs: legs,
          rationale: rationale
        )
      end
    end

    class ImplicationDetector < LogicalBundleDetector
      def scan(ctx : Context) : ScanResult
        result = ScanResult.new
        ctx.graph.by_type("implication").each do |rule|
          risk_flags = [] of String
          from = rule.from_token_id
          to = rule.to_token_id
          next unless from && to

          no_token = ctx.no_token_for_yes(from)
          unless no_token
            risk_flags << RiskFlags::MISSING_NO_TOKEN
            next
          end

          legs = [] of OpportunityLeg
          if leg = build_buy_leg(ctx, to, "Buy implied YES", "buy_yes", risk_flags)
            legs << leg
          end
          if leg = build_buy_leg(ctx, no_token, "Buy antecedent NO", "buy_no", risk_flags)
            legs << leg
          end
          next unless legs.size == 2

          if opp = finalize_opportunity(ctx, "Implication", rule, legs, risk_flags, "A implies B, so Buy B Yes + Buy A No has a payout floor of 1.")
            result.opportunities << opp
          end
        end
        result
      end
    end

    class MutexDetector < LogicalBundleDetector
      def scan(ctx : Context) : ScanResult
        result = ScanResult.new
        ctx.graph.by_type("mutually_exclusive").each do |rule|
          next unless rule.token_ids.size >= 2
          risk_flags = [] of String
          legs = [] of OpportunityLeg

          rule.token_ids.first(2).each do |yes_token|
            no_token = ctx.no_token_for_yes(yes_token)
            unless no_token
              risk_flags << RiskFlags::MISSING_NO_TOKEN
              next
            end
            if leg = build_buy_leg(ctx, no_token, "Buy mutually exclusive NO", "buy_no", risk_flags)
              legs << leg
            end
          end
          next unless legs.size == 2

          if opp = finalize_opportunity(ctx, "Mutex", rule, legs, risk_flags, "A and B are mutually exclusive, so Buy A No + Buy B No has a payout floor of 1.")
            result.opportunities << opp
          end
        end
        result
      end
    end

    class ExhaustiveGroupDetector < LogicalBundleDetector
      def scan(ctx : Context) : ScanResult
        result = ScanResult.new
        ctx.graph.by_type("exhaustive_group").each do |rule|
          next if rule.token_ids.empty?
          risk_flags = [] of String
          risk_flags << RiskFlags::UNVERIFIED_EXHAUSTIVENESS unless rule.verified_exhaustive
          legs = [] of OpportunityLeg

          rule.token_ids.each do |yes_token|
            if leg = build_buy_leg(ctx, yes_token, "Buy exhaustive YES", "buy_yes", risk_flags)
              legs << leg
            end
          end
          next unless legs.size == rule.token_ids.size

          if opp = finalize_opportunity(ctx, "ExhaustiveGroup", rule, legs, risk_flags, "Exactly one listed outcome is true, so buying all YES legs has a payout floor of 1.")
            result.opportunities << opp
          end
        end
        result
      end
    end
  end
end
