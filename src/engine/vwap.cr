require "../domain/models"

module PolyScan
  module Engine
    class VWAPResult
      getter requested_size : Fixed
      getter filled_size : Fixed
      getter notional : Fixed
      getter average_price : Fixed
      getter full_fill : Bool
      getter levels_taken : Int32

      def initialize(@requested_size : Fixed, @filled_size : Fixed, @notional : Fixed, @average_price : Fixed, @full_fill : Bool, @levels_taken : Int32)
      end

      def self.empty(requested_size : Fixed) : VWAPResult
        new(requested_size, Fixed.zero, Fixed.zero, Fixed.zero, false, 0)
      end
    end

    class VWAPEngine
      def self.buy(book : OrderBook, target_size : Fixed) : VWAPResult
        fill(book.asks, target_size)
      end

      def self.sell(book : OrderBook, target_size : Fixed) : VWAPResult
        fill(book.bids, target_size)
      end

      def self.fill(levels : Array(BookLevel), target_size : Fixed) : VWAPResult
        return VWAPResult.empty(target_size) unless target_size.positive?
        return VWAPResult.empty(target_size) if levels.empty?

        remaining = target_size
        filled = Fixed.zero
        notional = Fixed.zero
        levels_taken = 0

        levels.each do |level|
          break if remaining.zero?

          take = level.size < remaining ? level.size : remaining
          next unless take.positive?

          filled += take
          notional += level.price * take
          remaining -= take
          levels_taken += 1
        end

        average = filled.positive? ? notional / filled : Fixed.zero
        VWAPResult.new(target_size, filled, notional, average, remaining.zero?, levels_taken)
      end
    end
  end
end
