require "./context"
require "./logical_bundle"
require "./market_quality"
require "./model_edge"

module PolyScan
  module Detectors
    class Runner
      def self.run(ctx : Context) : ScanResult
        result = ScanResult.new
        detectors = [
          ModelEdgeDetector.new,
          ImplicationDetector.new,
          MutexDetector.new,
          ExhaustiveGroupDetector.new,
          SpreadAnomalyDetector.new,
          StalePriceDetector.new,
          BookImbalanceDetector.new,
        ]

        detectors.each do |detector|
          result.add(detector.scan(ctx))
        end

        result
      end
    end
  end
end
