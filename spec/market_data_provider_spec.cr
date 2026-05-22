require "./spec_helper"

class ProviderFakeGamma
  include PolyScan::App::GammaMarketSource

  def initialize(@events : Array(PolyScan::Event))
  end

  def fetch_market_events(max_markets : Int32) : Array(PolyScan::Event)
    @events.first(max_markets)
  end
end

class ProviderFakeClob
  include PolyScan::App::ClobBookSource

  getter requested : Array(String)

  def initialize(@books : Hash(String, PolyScan::OrderBook))
    @requested = [] of String
  end

  def fetch_book(token_id : String) : PolyScan::OrderBook
    @requested << token_id
    @books[token_id]? || raise "missing book"
  end
end

describe PolyScan::App::RealPolymarketProvider do
  it "filters ineligible listings and records book fetch diagnostics" do
    config = PolyScan::App::Config.new
    config.market_limit = 10
    config.book_limit = 10

    event = PolyScan::Event.new("event-real", "event-real", "Real Event", "test")
    event.markets = [
      market("condition-eligible", "eligible", true, false, false, true, [outcome("condition-eligible", "yes-eligible", "no-eligible")]),
      market("condition-inactive", "inactive", false, false, false, true, [outcome("condition-inactive", "yes-inactive", "no-inactive")]),
      market("condition-closed", "closed", true, true, false, true, [outcome("condition-closed", "yes-closed", "no-closed")]),
      market("condition-archived", "archived", true, false, true, true, [outcome("condition-archived", "yes-archived", "no-archived")]),
      market("condition-not-accepting", "not-accepting", true, false, false, false, [outcome("condition-not-accepting", "yes-not-accepting", "no-not-accepting")]),
      market("condition-missing-tokens", "missing-tokens", true, false, false, true, [] of PolyScan::Outcome),
    ]

    books = {
      "yes-eligible" => PolyScan::OrderBook.new(
        token_id: "yes-eligible",
        market_id: "condition-eligible",
        outcome_name: "Yes",
        bids: [PolyScan::BookLevel.new(fp("0.400000"), fp("2.000000"))],
        asks: [PolyScan::BookLevel.new(fp("0.500000"), fp("2.000000"))],
        fetched_at_unix_ms: Time.utc.to_unix_ms
      ),
    }
    clob = ProviderFakeClob.new(books)

    result = PolyScan::App::RealPolymarketProvider.new(config, ProviderFakeGamma.new([event]), clob).load

    result.markets.map(&.id).should eq(["condition-eligible"])
    result.events.size.should eq(1)
    result.events.first.markets.map(&.id).should eq(["condition-eligible"])
    result.books.size.should eq(1)
    clob.requested.should eq(["yes-eligible", "no-eligible"])

    reasons = result.skipped_listings.map(&.reason)
    reasons.should contain("inactive")
    reasons.should contain("closed")
    reasons.should contain("archived")
    reasons.should contain("not_accepting_orders")
    reasons.should contain("missing_clob_tokens")
    reasons.any? { |reason| reason.starts_with?("book_fetch_failed") }.should be_true
  end
end

private def market(id : String, slug : String, active : Bool, closed : Bool, archived : Bool, accepting_orders : Bool, outcomes : Array(PolyScan::Outcome)) : PolyScan::Market
  PolyScan::Market.new(
    id: id,
    event_id: "event-real",
    slug: slug,
    question: "#{slug}?",
    category: "test",
    end_time: "2026-12-31T00:00:00Z",
    active: active,
    outcomes: outcomes,
    gamma_id: "gamma-#{id}",
    condition_id: id,
    question_id: "question-#{id}",
    closed: closed,
    archived: archived,
    accepting_orders: accepting_orders
  )
end

private def outcome(market_id : String, yes_token : String, no_token : String) : PolyScan::Outcome
  PolyScan::Outcome.new(
    id: market_id,
    market_id: market_id,
    name: "Yes",
    yes_token_id: yes_token,
    no_token_id: no_token,
    p_hat: nil,
    confidence: fp("0.500000")
  )
end
