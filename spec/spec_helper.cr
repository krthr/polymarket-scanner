require "spec"
require "file_utils"
require "../src/app/application"
require "../src/engine/payout_proofs"

module SpecHelpers
  def fp(value : String) : PolyScan::Fixed
    PolyScan::Fixed.parse(value)
  end
end

include SpecHelpers
