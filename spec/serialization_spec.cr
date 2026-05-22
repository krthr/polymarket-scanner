require "./spec_helper"

describe "internal model JSON serialization" do
  it "serializes events, markets, and outcomes with explicit nulls and fixed-point strings" do
    outcome = PolyScan::Outcome.new(
      id: "outcome-1",
      market_id: "market-1",
      name: "Yes",
      yes_token_id: "yes-token",
      no_token_id: nil,
      p_hat: nil,
      confidence: fp("0.750000")
    )
    market = PolyScan::Market.new(
      id: "market-1",
      event_id: "event-1",
      slug: "market-one",
      question: "Will it happen?",
      category: "test",
      end_time: nil,
      active: true,
      outcomes: [outcome]
    )
    event = PolyScan::Event.new("event-1", "event-one", "Event One", "test", [market])

    root = JSON.parse(event.to_json).as_h
    market_json = root["markets"].as_a.first.as_h
    outcome_json = market_json["outcomes"].as_a.first.as_h

    market_json.has_key?("end_time").should be_true
    market_json["end_time"].raw.should be_nil
    outcome_json.has_key?("no_token_id").should be_true
    outcome_json["no_token_id"].raw.should be_nil
    outcome_json.has_key?("p_hat").should be_true
    outcome_json["p_hat"].raw.should be_nil
    outcome_json["confidence"].as_s.should eq("0.75")

    round_trip = PolyScan::Event.from_json(event.to_json)
    round_trip.markets.first.outcomes.first.confidence.should eq(fp("0.750000"))
  end

  it "serializes order books with validation errors and round-trips fixed levels" do
    book = PolyScan::OrderBook.new(
      token_id: "token-1",
      market_id: nil,
      outcome_name: nil,
      bids: [PolyScan::BookLevel.new(fp("1.100000"), fp("2.000000"))],
      asks: [PolyScan::BookLevel.new(fp("0.900000"), fp("0.000000"))],
      fetched_at_unix_ms: 123_i64,
      sequence: 7_i64
    )

    root = JSON.parse(book.to_json).as_h
    root.has_key?("market_id").should be_true
    root["market_id"].raw.should be_nil
    root.has_key?("outcome_name").should be_true
    root["outcome_name"].raw.should be_nil
    root["bids"].as_a.first.as_h["price"].as_s.should eq("1.1")
    root["validation_errors"].as_a.map(&.as_s).should contain("crossed book")

    round_trip = PolyScan::OrderBook.from_json(book.to_json)
    round_trip.bids.first.price.should eq(fp("1.100000"))
    round_trip.validation_errors.should contain("crossed book")
  end

  it "serializes opportunities and signals with existing status casing and computed fields" do
    leg = PolyScan::OpportunityLeg.new(
      action: "buy",
      token_id: "token-1",
      label: "Yes",
      size: fp("3.000000"),
      vwap_price: fp("0.500000"),
      notional: fp("1.500000"),
      fee: fp("0.050000")
    )
    opportunity = PolyScan::Opportunity.new(
      id: "opp-1",
      detector: "Detector",
      rule_id: nil,
      status: PolyScan::SignalStatus::Review,
      gross_edge: fp("0.300000"),
      fees: fp("0.050000"),
      edge_net: fp("0.250000"),
      score: fp("0.900000"),
      confidence: fp("0.800000"),
      risk_flags: [PolyScan::RiskFlags::LOW_DEPTH],
      legs: [leg],
      rationale: "test",
      payout_floor: fp("1.000000"),
      created_at_unix_ms: 456_i64
    )

    opportunity_json = JSON.parse(opportunity.to_json).as_h
    opportunity_json.has_key?("rule_id").should be_true
    opportunity_json["rule_id"].raw.should be_nil
    opportunity_json["status"].as_s.should eq("Review")
    opportunity_json["legs"].as_a.first.as_h["total_cost"].as_s.should eq("1.55")
    opportunity_json["total_notional"].as_s.should eq("1.5")
    opportunity_json["total_cost"].as_s.should eq("1.55")
    PolyScan::Opportunity.from_json(opportunity.to_json).status.should eq(PolyScan::SignalStatus::Review)

    signal = PolyScan::Signal.new(
      id: "signal-1",
      detector: "Detector",
      market_id: nil,
      token_ids: ["token-1"],
      status: PolyScan::SignalStatus::Priority,
      edge_net: fp("0.250000"),
      score: fp("0.900000"),
      confidence: fp("0.800000"),
      risk_flags: [] of String,
      rationale: "test",
      created_at_unix_ms: 789_i64
    )

    signal_json = JSON.parse(signal.to_json).as_h
    signal_json.has_key?("market_id").should be_true
    signal_json["market_id"].raw.should be_nil
    signal_json["status"].as_s.should eq("Priority")
    PolyScan::Signal.from_json(signal.to_json).status.should eq(PolyScan::SignalStatus::Priority)
  end

  it "serializes relationship rules and paper trades through generated serializers" do
    rule = PolyScan::RelationshipRule.new(
      id: "rule-1",
      type: "implication",
      description: nil,
      from_token_id: "from-token",
      to_token_id: nil,
      token_ids: ["from-token", "to-token"],
      confidence: fp("0.600000"),
      quality: fp("0.700000")
    )

    rule_json = JSON.parse(rule.to_json).as_h
    rule_json.has_key?("description").should be_true
    rule_json["description"].raw.should be_nil
    rule_json.has_key?("to_token_id").should be_true
    rule_json["to_token_id"].raw.should be_nil
    rule_json["confidence"].as_s.should eq("0.6")
    PolyScan::RelationshipRule.from_json(rule.to_json).quality.should eq(fp("0.700000"))

    leg = PolyScan::OpportunityLeg.new("buy", "token-1", "Yes", fp("1.000000"), fp("0.400000"), fp("0.400000"), fp("0.010000"))
    trade = PolyScan::Paper::PaperTrade.new(
      id: "paper-1",
      opportunity_id: "opp-1",
      status: "paper_open",
      legs: [leg],
      total_cost: fp("0.410000"),
      expected_payout: fp("1.000000"),
      created_at_unix_ms: 999_i64
    )

    trade_json = JSON.parse(trade.to_json).as_h
    trade_json["total_cost"].as_s.should eq("0.41")
    trade_json["expected_payout"].as_s.should eq("1")
    trade_json["legs"].as_a.first.as_h["total_cost"].as_s.should eq("0.41")
    PolyScan::Paper::PaperTrade.from_json(trade.to_json).expected_payout.should eq(fp("1.000000"))
  end
end
