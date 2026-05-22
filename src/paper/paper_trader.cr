require "json"
require "../domain/models"

module PolyScan
  module Paper
    class PaperTrade
      include JSON::Serializable

      getter id : String
      getter opportunity_id : String
      getter status : String
      getter legs : Array(OpportunityLeg)
      getter total_cost : Fixed
      getter expected_payout : Fixed
      getter created_at_unix_ms : Int64

      def initialize(@id : String, @opportunity_id : String, @status : String, @legs : Array(OpportunityLeg), @total_cost : Fixed, @expected_payout : Fixed, @created_at_unix_ms : Int64 = Time.utc.to_unix_ms)
      end
    end

    class PaperTrader
      def initialize(@enabled : Bool)
      end

      def create_for(opportunities : Array(Opportunity)) : Array(PaperTrade)
        return [] of PaperTrade unless @enabled

        first = opportunities.find { |opp| opp.detector == "Implication" || opp.detector == "Mutex" || opp.detector == "ExhaustiveGroup" }
        return [] of PaperTrade unless first

        [
          PaperTrade.new(
            id: "paper-#{first.id}",
            opportunity_id: first.id,
            status: "paper_open",
            legs: first.legs,
            total_cost: first.total_cost,
            expected_payout: first.payout_floor
          ),
        ]
      end
    end
  end
end
