require "json"
require "../domain/models"

module PolyScan
  module Clients
    module APIModels
      module StringLikeConverter
        def self.from_json(pull : JSON::PullParser) : String?
          value = JSON::Any.new(pull)
          value.as_s? || value.raw.try { value.to_json }
        end

        def self.to_json(value : String?, json : JSON::Builder) : Nil
          value.nil? ? json.null : json.string(value)
        end
      end

      module Int64LikeConverter
        def self.from_json(pull : JSON::PullParser) : Int64?
          value = JSON::Any.new(pull)
          value.as_i64? || value.as_s?.try(&.to_i64?)
        end

        def self.to_json(value : Int64?, json : JSON::Builder) : Nil
          value.nil? ? json.null : json.number(value)
        end
      end

      module StringArrayConverter
        def self.from_json(pull : JSON::PullParser) : Array(String)?
          value = JSON::Any.new(pull)
          strings_from(value)
        end

        def self.to_json(value : Array(String)?, json : JSON::Builder) : Nil
          value.to_json(json)
        end

        def self.strings_from(value : JSON::Any?) : Array(String)?
          return nil unless value

          if array = value.as_a?
            return array.map { |item| item.as_s? || item.to_json }
          end

          if string = value.as_s?
            parsed = JSON.parse(string)
            return parsed.as_a.map { |item| item.as_s? || item.to_json }
          end

          nil
        end
      end

      struct GammaOutcomes
        getter objects : Array(GammaOutcome)?
        getter names : Array(String)?

        def initialize(@objects : Array(GammaOutcome)? = nil, @names : Array(String)? = nil)
        end
      end

      module GammaOutcomesConverter
        def self.from_json(pull : JSON::PullParser) : GammaOutcomes?
          value = JSON::Any.new(pull)
          return nil if value.raw.nil?

          if array = value.as_a?
            first = array.first?
            if first && first.as_h?
              return GammaOutcomes.new(objects: array.map { |item| GammaOutcome.from_json(item.to_json) })
            end

            return GammaOutcomes.new(names: array.map { |item| item.as_s? || item.to_json })
          end

          if names = StringArrayConverter.strings_from(value)
            return GammaOutcomes.new(names: names)
          end

          nil
        end

        def self.to_json(value : GammaOutcomes?, json : JSON::Builder) : Nil
          if value.nil?
            json.null
          elsif objects = value.objects
            objects.to_json(json)
          else
            value.names.to_json(json)
          end
        end
      end

      class GammaEventsEnvelope
        include JSON::Serializable

        getter events : Array(GammaEvent) = [] of GammaEvent

        def to_domain : Array(Event)
          @events.map(&.to_domain)
        end
      end

      class GammaEvent
        include JSON::Serializable

        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter id : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter slug : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter title : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter name : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter category : String?
        getter markets : Array(GammaMarket) = [] of GammaMarket

        def to_domain : Event
          id = @id || "event-unknown"
          slug = @slug || id
          title = @title || @name || slug
          category = @category || "unknown"
          event = Event.new(id, slug, title, category)
          event.markets = @markets.map { |market| market.to_domain(event) }
          event
        end
      end

      class GammaMarket
        include JSON::Serializable

        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter id : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter slug : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter question : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter title : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter category : String?
        @[JSON::Field(key: "endDate", converter: APIModels::StringLikeConverter)]
        getter end_date : String?
        @[JSON::Field(key: "end_time", converter: APIModels::StringLikeConverter)]
        getter end_time : String?
        getter active : Bool?
        @[JSON::Field(key: "outcomes", converter: APIModels::GammaOutcomesConverter)]
        getter outcomes_payload : GammaOutcomes?
        @[JSON::Field(key: "clobTokenIds", converter: APIModels::StringArrayConverter)]
        getter clob_token_ids : Array(String)?
        @[JSON::Field(key: "clob_token_ids", converter: APIModels::StringArrayConverter)]
        getter clob_token_ids_alt : Array(String)?

        def to_domain(event : Event) : Market
          id = @id || "market-unknown"
          slug = @slug || id
          question = @question || @title || slug
          category = @category || event.category
          market = Market.new(id, event.id, slug, question, category, @end_date || @end_time, @active.nil? ? true : @active.not_nil!)
          market.outcomes = domain_outcomes(market)
          market
        end

        private def domain_outcomes(market : Market) : Array(Outcome)
          if payload = @outcomes_payload
            if objects = payload.objects
              return objects.map { |outcome| outcome.to_domain(market) }
            end
          end

          names = @outcomes_payload.try(&.names) || [] of String
          token_ids = @clob_token_ids || @clob_token_ids_alt || [] of String
          if names.size == 2 && names[0].downcase == "yes" && names[1].downcase == "no" && token_ids.size >= 2
            [Outcome.new(market.id, market.id, market.question, token_ids[0], token_ids[1], nil, Fixed.parse("0.500000"))]
          else
            names.each_with_index.map do |name, index|
              token = token_ids[index]? || "#{market.id}-#{name.downcase}"
              Outcome.new("#{market.id}-#{index}", market.id, name, token, nil, nil, Fixed.parse("0.500000"))
            end.to_a
          end
        end
      end

      class GammaOutcome
        include JSON::Serializable

        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter id : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter name : String?
        @[JSON::Field(key: "yes_token_id", converter: APIModels::StringLikeConverter)]
        getter yes_token_id : String?
        @[JSON::Field(key: "token_id", converter: APIModels::StringLikeConverter)]
        getter token_id : String?
        @[JSON::Field(key: "no_token_id", converter: APIModels::StringLikeConverter)]
        getter no_token_id : String?
        getter p_hat : Fixed?
        getter confidence : Fixed?
        getter external_source_stale : Bool?

        def to_domain(market : Market) : Outcome
          id = @id || @name || "outcome"
          name = @name || id
          yes_token_id = @yes_token_id || @token_id || id
          Outcome.new(id, market.id, name, yes_token_id, @no_token_id, @p_hat, @confidence || Fixed.parse("0.500000"), @external_source_stale || false)
        end
      end

      class ClobBook
        include JSON::Serializable

        @[JSON::Field(key: "token_id", converter: APIModels::StringLikeConverter)]
        getter token_id : String?
        @[JSON::Field(key: "asset_id", converter: APIModels::StringLikeConverter)]
        getter asset_id : String?
        @[JSON::Field(key: "market_id", converter: APIModels::StringLikeConverter)]
        getter market_id : String?
        @[JSON::Field(key: "market", converter: APIModels::StringLikeConverter)]
        getter market : String?
        @[JSON::Field(key: "outcome_name", converter: APIModels::StringLikeConverter)]
        getter outcome_name : String?
        @[JSON::Field(key: "fetched_at_unix_ms", converter: APIModels::Int64LikeConverter)]
        getter fetched_at_unix_ms : Int64?
        @[JSON::Field(converter: APIModels::Int64LikeConverter)]
        getter timestamp : Int64?
        @[JSON::Field(converter: APIModels::Int64LikeConverter)]
        getter sequence : Int64?
        getter bids : Array(ClobBookLevel) = [] of ClobBookLevel
        getter asks : Array(ClobBookLevel) = [] of ClobBookLevel

        def to_domain : OrderBook
          OrderBook.new(
            @token_id || @asset_id || "token-unknown",
            @market_id || @market,
            @outcome_name,
            @bids.map(&.to_domain).sort_by { |level| -level.price.atoms },
            @asks.map(&.to_domain).sort_by { |level| level.price.atoms },
            timestamp_ms,
            @sequence || 0_i64
          )
        end

        private def timestamp_ms : Int64
          explicit = @fetched_at_unix_ms || 0_i64
          return explicit if explicit > 0

          raw = @timestamp || 0_i64
          return Time.utc.to_unix_ms if raw <= 0
          raw < 10_000_000_000_i64 ? raw * 1000 : raw
        end
      end

      class ClobBookLevel
        include JSON::Serializable

        getter price : String?
        getter size : String?

        def to_domain : BookLevel
          BookLevel.new(
            Fixed.parse(decimal_string(@price, "price")),
            Fixed.parse(decimal_string(@size, "size"))
          )
        end

        private def decimal_string(value : String?, key : String) : String
          raise ArgumentError.new("book level missing #{key}") unless value
          value
        end
      end

      class ClobSamplingResponse
        include JSON::Serializable

        @[JSON::Field(key: "next_cursor", converter: APIModels::StringLikeConverter)]
        getter next_cursor : String?
        getter data : Array(ClobSamplingMarket) = [] of ClobSamplingMarket

        def to_domain_markets : Array(Market)
          @data.compact_map(&.to_domain)
        end
      end

      class ClobSamplingMarket
        include JSON::Serializable

        @[JSON::Field(key: "enable_order_book")]
        getter enable_order_book : Bool?
        getter active : Bool?
        getter closed : Bool?
        getter archived : Bool?
        @[JSON::Field(key: "accepting_orders")]
        getter accepting_orders : Bool?
        @[JSON::Field(key: "condition_id", converter: APIModels::StringLikeConverter)]
        getter condition_id : String?
        @[JSON::Field(key: "question_id", converter: APIModels::StringLikeConverter)]
        getter question_id : String?
        @[JSON::Field(key: "market_slug", converter: APIModels::StringLikeConverter)]
        getter market_slug : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter question : String?
        @[JSON::Field(key: "end_date_iso", converter: APIModels::StringLikeConverter)]
        getter end_date_iso : String?
        getter tokens : Array(ClobToken) = [] of ClobToken

        def to_domain : Market?
          return nil unless bool(@active, false)
          return nil if bool(@closed, false)
          return nil if bool(@archived, false)
          return nil unless bool(@accepting_orders, true)
          return nil unless bool(@enable_order_book, true)

          market_id = @condition_id || @question_id || @market_slug
          return nil unless market_id

          market = Market.new(
            id: market_id,
            event_id: "clob-sampling",
            slug: @market_slug || market_id,
            question: @question || @market_slug || market_id,
            category: "live",
            end_time: @end_date_iso,
            active: true,
            condition_id: @condition_id,
            question_id: @question_id,
            closed: false,
            archived: false,
            accepting_orders: true
          )
          market.outcomes = domain_outcomes(market)
          return nil if market.outcomes.empty?
          market
        end

        private def domain_outcomes(market : Market) : Array(Outcome)
          yes_token = @tokens.find { |token| token.outcome.try(&.downcase) == "yes" }
          no_token = @tokens.find { |token| token.outcome.try(&.downcase) == "no" }

          if yes_token && no_token
            return [
              Outcome.new(
                market.id,
                market.id,
                market.question,
                yes_token.token_id || "missing-yes-token",
                no_token.token_id || "missing-no-token",
                nil,
                Fixed.parse("0.500000")
              ),
            ]
          end

          @tokens.compact_map do |token|
            token_id = token.token_id
            outcome_name = token.outcome
            next unless token_id && outcome_name

            Outcome.new(
              "#{market.id}-#{outcome_name}",
              market.id,
              outcome_name,
              token_id,
              nil,
              nil,
              Fixed.parse("0.500000")
            )
          end
        end

        private def bool(value : Bool?, default : Bool) : Bool
          value.nil? ? default : value.not_nil!
        end
      end

      class ClobToken
        include JSON::Serializable

        @[JSON::Field(key: "token_id", converter: APIModels::StringLikeConverter)]
        getter token_id : String?
        @[JSON::Field(converter: APIModels::StringLikeConverter)]
        getter outcome : String?
      end
    end
  end
end
