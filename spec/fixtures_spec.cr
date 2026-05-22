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
end
