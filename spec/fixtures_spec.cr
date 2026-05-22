require "./spec_helper"

describe "fixture parsing" do
  it "parses a Gamma event fixture into normalized markets and outcomes" do
    events = PolyScan::Clients::GammaClient.events_from_file("spec/fixtures/gamma_event.json")
    events.size.should eq(1)
    events.first.markets.size.should eq(3)
    events.first.markets.first.outcomes.first.yes_token_id.should eq("yes_rain")
    events.first.markets.first.outcomes.first.no_token_id.should eq("no_rain")
  end

  it "parses a CLOB book fixture into fixed-point levels" do
    book = PolyScan::Clients::ClobClient.book_from_file("spec/fixtures/books/yes_wet_ground.json")
    book.token_id.should eq("yes_wet_ground")
    book.top_ask.not_nil!.price.should eq(fp("0.520000"))
    book.top_bid.not_nil!.size.should eq(fp("8.000000"))
  end

  it "parses live CLOB sampling markets without using token prices as trading-critical floats" do
    root = JSON.parse(File.read("spec/fixtures/clob_sampling_markets.json"))
    markets = PolyScan::Clients::ClobClient.parse_sampling_markets(root)
    markets.size.should eq(1)
    markets.first.id.should eq("0xlivecondition")
    markets.first.outcomes.first.yes_token_id.should eq("live_yes_token")
    markets.first.outcomes.first.no_token_id.should eq("live_no_token")
  end
end
