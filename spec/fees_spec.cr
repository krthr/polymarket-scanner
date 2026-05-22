require "./spec_helper"

describe PolyScan::Engine::TakerFeeEngine do
  it "charges bps on min(price, 1-price) times size" do
    engine = PolyScan::Engine::TakerFeeEngine.new(200)
    engine.fee(fp("0.600000"), fp("2.000000")).should eq(fp("0.016000"))
    engine.fee(fp("0.200000"), fp("3.000000")).should eq(fp("0.012000"))
  end
end
