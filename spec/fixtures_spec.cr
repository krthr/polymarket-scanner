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

  it "parses real Gamma market listings with explicit Polymarket identifiers and events" do
    root = JSON.parse(File.read("spec/fixtures/gamma_markets_page.json"))
    events, next_cursor = PolyScan::Clients::GammaClient.parse_market_listing_page(root)

    next_cursor.should eq("")
    events.first.id.should eq("23784")
    events.first.slug.should eq("what-will-happen-before-gta-vi")

    market = events.first.markets.first
    market.id.should eq("0x1fad72fae204143ff1c3035e99e7c0f65ea8d5cd9bd1070987bd1a3316f772be")
    market.gamma_id.should eq("540817")
    market.condition_id.should eq("0x1fad72fae204143ff1c3035e99e7c0f65ea8d5cd9bd1070987bd1a3316f772be")
    market.question_id.should eq("0xquestion")
    market.accepting_orders.should be_true
    market.closed.should be_false
    market.archived.should be_false
    market.outcomes.first.yes_token_id.should eq("98022490269692409998126496127597032490334070080325855126491859374983463996227")
    market.outcomes.first.no_token_id.should eq("53831553061883006530739877284105938919721408776239639687877978808906551086026")

    missing_token_market = events.find { |event| event.id == "missing-event" }.not_nil!.markets.first
    missing_token_market.outcomes.should be_empty
  end
end
