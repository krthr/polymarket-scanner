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

  module SignalStatusJSONConverter
    def self.from_json(pull : JSON::PullParser) : SignalStatus
      SignalStatus.parse(pull.read_string)
    end

    def self.to_json(value : SignalStatus, json : JSON::Builder) : Nil
      json.string(value.to_s)
    end
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
    include JSON::Serializable

    getter id : String
    getter slug : String
    getter title : String
    getter category : String
    property markets : Array(Market)

    def initialize(@id : String, @slug : String, @title : String, @category : String, @markets = [] of Market)
    end
  end

  @[JSON::Serializable::Options(emit_nulls: true)]
  class Market
    include JSON::Serializable

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
  end

  @[JSON::Serializable::Options(emit_nulls: true)]
  class Outcome
    include JSON::Serializable

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
  end

  class BookLevel
    include JSON::Serializable

    getter price : Fixed
    getter size : Fixed

    def initialize(@price : Fixed, @size : Fixed)
    end
  end

  @[JSON::Serializable::Options(emit_nulls: true)]
  class OrderBook
    include JSON::Serializable

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

    protected def on_to_json(json : JSON::Builder) : Nil
      json.field "validation_errors", validation_errors
    end
  end

  class OpportunityLeg
    include JSON::Serializable

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

    protected def on_to_json(json : JSON::Builder) : Nil
      json.field "total_cost", total_cost
    end
  end

  @[JSON::Serializable::Options(emit_nulls: true)]
  class Opportunity
    include JSON::Serializable

    getter id : String
    getter detector : String
    getter rule_id : String?
    @[JSON::Field(converter: PolyScan::SignalStatusJSONConverter)]
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

    protected def on_to_json(json : JSON::Builder) : Nil
      json.field "total_notional", total_notional
      json.field "total_cost", total_cost
    end
  end

  @[JSON::Serializable::Options(emit_nulls: true)]
  class Signal
    include JSON::Serializable

    getter id : String
    getter detector : String
    getter market_id : String?
    getter token_ids : Array(String)
    @[JSON::Field(converter: PolyScan::SignalStatusJSONConverter)]
    getter status : SignalStatus
    getter edge_net : Fixed
    getter score : Fixed
    getter confidence : Fixed
    getter risk_flags : Array(String)
    getter rationale : String
    getter created_at_unix_ms : Int64

    def initialize(@id : String, @detector : String, @market_id : String?, @token_ids : Array(String), @status : SignalStatus, @edge_net : Fixed, @score : Fixed, @confidence : Fixed, @risk_flags : Array(String), @rationale : String, @created_at_unix_ms : Int64 = Time.utc.to_unix_ms)
    end
  end
end
