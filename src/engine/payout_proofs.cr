module PolyScan
  module Engine
    module PayoutProofs
      def self.implication_min_payout : Int32
        payouts = [] of Int32
        [{false, false}, {false, true}, {true, true}].each do |a_true, b_true|
          payouts << ((b_true ? 1 : 0) + (a_true ? 0 : 1))
        end
        payouts.min
      end

      def self.mutex_min_payout : Int32
        payouts = [] of Int32
        [{false, false}, {true, false}, {false, true}].each do |a_true, b_true|
          payouts << ((a_true ? 0 : 1) + (b_true ? 0 : 1))
        end
        payouts.min
      end

      def self.exhaustive_group_min_payout(leg_count : Int32) : Int32
        raise ArgumentError.new("leg_count must be positive") unless leg_count > 0
        1
      end
    end
  end
end
