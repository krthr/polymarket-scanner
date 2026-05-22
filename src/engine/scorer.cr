require "../domain/models"

module PolyScan
  module Engine
    class ScoreBreakdown
      getter gross_edge : Fixed
      getter fees : Fixed
      getter slippage_buffer : Fixed
      getter uncertainty_penalty : Fixed
      getter resolution_penalty : Fixed
      getter stale_book_penalty : Fixed
      getter edge_net : Fixed
      getter score : Fixed
      getter status : SignalStatus

      def initialize(@gross_edge : Fixed, @fees : Fixed, @slippage_buffer : Fixed, @uncertainty_penalty : Fixed, @resolution_penalty : Fixed, @stale_book_penalty : Fixed, @edge_net : Fixed, @score : Fixed, @status : SignalStatus)
      end
    end

    class Scorer
      OBSERVE_THRESHOLD   = Fixed.parse("0.001000")
      CANDIDATE_THRESHOLD = Fixed.parse("0.010000")
      REVIEW_THRESHOLD    = Fixed.parse("0.025000")
      PRIORITY_THRESHOLD  = Fixed.parse("0.050000")

      def self.score(
        gross_edge : Fixed,
        fees : Fixed,
        slippage_buffer : Fixed,
        uncertainty_penalty : Fixed,
        resolution_penalty : Fixed,
        stale_book_penalty : Fixed,
        confidence_factor : Fixed,
        liquidity_factor : Fixed,
        freshness_factor : Fixed,
        rule_quality_factor : Fixed,
      ) : ScoreBreakdown
        edge_net = gross_edge - fees - slippage_buffer - uncertainty_penalty - resolution_penalty - stale_book_penalty
        raw_score = edge_net * confidence_factor * liquidity_factor * freshness_factor * rule_quality_factor
        status = classify(raw_score, edge_net)
        ScoreBreakdown.new(gross_edge, fees, slippage_buffer, uncertainty_penalty, resolution_penalty, stale_book_penalty, edge_net, raw_score, status)
      end

      def self.classify(score : Fixed, edge_net : Fixed) : SignalStatus
        return SignalStatus::Rejected unless edge_net.positive?
        return SignalStatus::Observe if score < CANDIDATE_THRESHOLD
        return SignalStatus::Candidate if score < REVIEW_THRESHOLD
        return SignalStatus::Review if score < PRIORITY_THRESHOLD
        SignalStatus::Priority
      end
    end
  end
end
