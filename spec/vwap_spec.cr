require "./spec_helper"

describe PolyScan::Engine::VWAPEngine do
  it "returns an empty result for empty books" do
    book = PolyScan::OrderBook.new("empty", nil, nil, [] of PolyScan::BookLevel, [] of PolyScan::BookLevel, Time.utc.to_unix_ms)
    fill = PolyScan::Engine::VWAPEngine.buy(book, fp("1.000000"))
    fill.full_fill.should be_false
    fill.filled_size.should eq(fp("0"))
    fill.notional.should eq(fp("0"))
  end

  it "reports partial fills" do
    levels = [PolyScan::BookLevel.new(fp("0.400000"), fp("1.000000"))]
    fill = PolyScan::Engine::VWAPEngine.fill(levels, fp("2.000000"))
    fill.full_fill.should be_false
    fill.filled_size.should eq(fp("1.000000"))
    fill.average_price.should eq(fp("0.400000"))
  end

  it "fills a single level fully" do
    levels = [PolyScan::BookLevel.new(fp("0.400000"), fp("2.000000"))]
    fill = PolyScan::Engine::VWAPEngine.fill(levels, fp("1.000000"))
    fill.full_fill.should be_true
    fill.notional.should eq(fp("0.400000"))
    fill.average_price.should eq(fp("0.400000"))
  end

  it "computes multi-level VWAP" do
    levels = [
      PolyScan::BookLevel.new(fp("0.400000"), fp("1.000000")),
      PolyScan::BookLevel.new(fp("0.600000"), fp("1.000000")),
    ]
    fill = PolyScan::Engine::VWAPEngine.fill(levels, fp("2.000000"))
    fill.full_fill.should be_true
    fill.levels_taken.should eq(2)
    fill.notional.should eq(fp("1.000000"))
    fill.average_price.should eq(fp("0.500000"))
  end
end
