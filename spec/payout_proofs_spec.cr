require "./spec_helper"

describe PolyScan::Engine::PayoutProofs do
  it "proves implication bundle payout floor" do
    PolyScan::Engine::PayoutProofs.implication_min_payout.should eq(1)
  end

  it "proves mutex bundle payout floor" do
    PolyScan::Engine::PayoutProofs.mutex_min_payout.should eq(1)
  end

  it "proves exhaustive group payout floor" do
    PolyScan::Engine::PayoutProofs.exhaustive_group_min_payout(3).should eq(1)
  end
end
