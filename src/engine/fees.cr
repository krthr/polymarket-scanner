require "./vwap"

module PolyScan
  module Engine
    class TakerFeeEngine
      getter taker_fee_bps : Int32

      def initialize(@taker_fee_bps : Int32)
      end

      def fee(price : Fixed, size : Fixed) : Fixed
        base_price = price.min(Fixed.one - price)
        (base_price * size).bps(@taker_fee_bps)
      end

      def fee_for_fill(fill : VWAPResult) : Fixed
        return Fixed.zero unless fill.filled_size.positive?
        fee(fill.average_price, fill.filled_size)
      end
    end
  end
end
