require "json"
require "./fixed"

module PolyScan
  enum SignalStatus
    Rejected
    Observe
    Candidate
    Review
    Priority
  end

  module RiskFlags
    STALE_BOOK                = "stale book"
    LOW_DEPTH                 = "low depth"
    WIDE_SPREAD               = "wide spread"
    HIGH_FEES                 = "high fees"
    LOW_CONFIDENCE            = "low confidence"
    AMBIGUOUS_NEAR_RESOLUTION = "ambiguous/near resolution"
    MISSING_NO_TOKEN          = "missing NO token"
    UNVERIFIED_EXHAUSTIVENESS = "unverified exhaustiveness"
    STALE_EXTERNAL_SOURCE     = "stale external source"
    HIGH_CORRELATION          = "high correlation"
    UNKNOWN_CATEGORY          = "unknown category"
    NEG_RISK_COMPLEXITY       = "neg-risk complexity"
  end

  class Event
    getter id : String
    getter slug : String
    getter title : String
    getter category : String
    property markets : Array(Market)

    def initialize(@id : String, @slug : String, @title : String, @category : String, @markets = [] of Market)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "id", @id
        json.field "slug", @slug
        json.field "title", @title
        json.field "category", @category
        json.field "markets", @markets
      end
    end
  end

  class Market
    getter id : String
    getter event_id : String
    getter slug : String
    getter question : String
    getter category : String
    getter end_time : String?
    getter active : Bool
    property outcomes : Array(Outcome)

    def initialize(@id : String, @event_id : String, @slug : String, @question : String, @category : String, @end_time : String?, @active : Bool, @outcomes = [] of Outcome)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "id", @id
        json.field "event_id", @event_id
        json.field "slug", @slug
        json.field "question", @question
        json.field "category", @category
        json.field "end_time", @end_time
        json.field "active", @active
        json.field "outcomes", @outcomes
      end
    end
  end

  class Outcome
    getter id : String
    getter market_id : String
    getter name : String
    getter yes_token_id : String
    getter no_token_id : String?
    getter p_hat : Fixed?
    getter confidence : Fixed
    getter external_source_stale : Bool

    def initialize(@id : String, @market_id : String, @name : String, @yes_token_id : String, @no_token_id : String?, @p_hat : Fixed?, @confidence : Fixed, @external_source_stale : Bool = false)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "id", @id
        json.field "market_id", @market_id
        json.field "name", @name
        json.field "yes_token_id", @yes_token_id
        json.field "no_token_id", @no_token_id
        json.field "p_hat", @p_hat
        json.field "confidence", @confidence
        json.field "external_source_stale", @external_source_stale
      end
    end
  end

  class BookLevel
    getter price : Fixed
    getter size : Fixed

    def initialize(@price : Fixed, @size : Fixed)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "price", @price
        json.field "size", @size
      end
    end
  end

  class OrderBook
    getter token_id : String
    getter market_id : String?
    getter outcome_name : String?
    getter bids : Array(BookLevel)
    getter asks : Array(BookLevel)
    getter fetched_at_unix_ms : Int64
    getter sequence : Int64

    def initialize(@token_id : String, @market_id : String?, @outcome_name : String?, @bids : Array(BookLevel), @asks : Array(BookLevel), @fetched_at_unix_ms : Int64, @sequence : Int64 = 0_i64)
    end

    def top_bid : BookLevel?
      @bids.first?
    end

    def top_ask : BookLevel?
      @asks.first?
    end

    def spread : Fixed?
      bid = top_bid
      ask = top_ask
      return nil unless bid && ask
      ask.price - bid.price
    end

    def ask_depth : Fixed
      @asks.reduce(Fixed.zero) { |sum, level| sum + level.size }
    end

    def bid_depth : Fixed
      @bids.reduce(Fixed.zero) { |sum, level| sum + level.size }
    end

    def stale?(max_age_ms : Int64, now_ms : Int64 = Time.utc.to_unix_ms) : Bool
      now_ms - @fetched_at_unix_ms > max_age_ms
    end

    def validation_errors : Array(String)
      errors = [] of String
      validate_side(@asks, ascending: true, name: "asks", errors: errors)
      validate_side(@bids, ascending: false, name: "bids", errors: errors)
      if bid = top_bid
        if ask = top_ask
          errors << "crossed book" if bid.price >= ask.price
        end
      end
      errors
    end

    private def validate_side(levels : Array(BookLevel), ascending : Bool, name : String, errors : Array(String)) : Nil
      previous : Fixed? = nil
      levels.each do |level|
        errors << "#{name} price out of range" if level.price < Fixed.zero || level.price > Fixed.one
        errors << "#{name} size must be positive" unless level.size.positive?
        if prev = previous
          if ascending
            errors << "#{name} not sorted ascending" if level.price < prev
          else
            errors << "#{name} not sorted descending" if level.price > prev
          end
        end
        previous = level.price
      end
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "token_id", @token_id
        json.field "market_id", @market_id
        json.field "outcome_name", @outcome_name
        json.field "bids", @bids
        json.field "asks", @asks
        json.field "fetched_at_unix_ms", @fetched_at_unix_ms
        json.field "sequence", @sequence
        json.field "validation_errors", validation_errors
      end
    end
  end

  class OpportunityLeg
    getter action : String
    getter token_id : String
    getter label : String
    getter size : Fixed
    getter vwap_price : Fixed
    getter notional : Fixed
    getter fee : Fixed

    def initialize(@action : String, @token_id : String, @label : String, @size : Fixed, @vwap_price : Fixed, @notional : Fixed, @fee : Fixed)
    end

    def total_cost : Fixed
      @notional + @fee
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "action", @action
        json.field "token_id", @token_id
        json.field "label", @label
        json.field "size", @size
        json.field "vwap_price", @vwap_price
        json.field "notional", @notional
        json.field "fee", @fee
        json.field "total_cost", total_cost
      end
    end
  end

  class Opportunity
    getter id : String
    getter detector : String
    getter rule_id : String?
    getter status : SignalStatus
    getter gross_edge : Fixed
    getter fees : Fixed
    getter edge_net : Fixed
    getter score : Fixed
    getter confidence : Fixed
    getter risk_flags : Array(String)
    getter legs : Array(OpportunityLeg)
    getter rationale : String
    getter payout_floor : Fixed
    getter created_at_unix_ms : Int64

    def initialize(@id : String, @detector : String, @rule_id : String?, @status : SignalStatus, @gross_edge : Fixed, @fees : Fixed, @edge_net : Fixed, @score : Fixed, @confidence : Fixed, @risk_flags : Array(String), @legs : Array(OpportunityLeg), @rationale : String, @payout_floor : Fixed = Fixed.one, @created_at_unix_ms : Int64 = Time.utc.to_unix_ms)
    end

    def total_notional : Fixed
      @legs.reduce(Fixed.zero) { |sum, leg| sum + leg.notional }
    end

    def total_cost : Fixed
      total_notional + @fees
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "id", @id
        json.field "detector", @detector
        json.field "rule_id", @rule_id
        json.field "status", @status.to_s
        json.field "gross_edge", @gross_edge
        json.field "fees", @fees
        json.field "edge_net", @edge_net
        json.field "score", @score
        json.field "confidence", @confidence
        json.field "risk_flags", @risk_flags
        json.field "legs", @legs
        json.field "rationale", @rationale
        json.field "payout_floor", @payout_floor
        json.field "total_notional", total_notional
        json.field "total_cost", total_cost
        json.field "created_at_unix_ms", @created_at_unix_ms
      end
    end
  end

  class Signal
    getter id : String
    getter detector : String
    getter market_id : String?
    getter token_ids : Array(String)
    getter status : SignalStatus
    getter edge_net : Fixed
    getter score : Fixed
    getter confidence : Fixed
    getter risk_flags : Array(String)
    getter rationale : String
    getter created_at_unix_ms : Int64

    def initialize(@id : String, @detector : String, @market_id : String?, @token_ids : Array(String), @status : SignalStatus, @edge_net : Fixed, @score : Fixed, @confidence : Fixed, @risk_flags : Array(String), @rationale : String, @created_at_unix_ms : Int64 = Time.utc.to_unix_ms)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "id", @id
        json.field "detector", @detector
        json.field "market_id", @market_id
        json.field "token_ids", @token_ids
        json.field "status", @status.to_s
        json.field "edge_net", @edge_net
        json.field "score", @score
        json.field "confidence", @confidence
        json.field "risk_flags", @risk_flags
        json.field "rationale", @rationale
        json.field "created_at_unix_ms", @created_at_unix_ms
      end
    end
  end
end
