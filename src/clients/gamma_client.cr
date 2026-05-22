require "json"
require "./http_client"
require "../domain/models"

module PolyScan
  module Clients
    class GammaClient
      def initialize(@http : HttpClient)
      end

      def fetch_events(limit : Int32 = 50) : Array(Event)
        parse_events(@http.get("/events?limit=#{limit}&active=true"))
      end

      def self.events_from_file(path : String) : Array(Event)
        parse_events(File.read(path))
      end

      def self.parse_events(body : String) : Array(Event)
        root = JSON.parse(body)
        event_nodes = root["events"]?.try(&.as_a) || root.as_a? || [root]
        event_nodes.map { |node| parse_event(node) }
      end

      private def self.parse_event(node : JSON::Any) : Event
        id = string(node, "id", "event-unknown")
        slug = string(node, "slug", id)
        title = string(node, "title", string(node, "name", slug))
        category = string(node, "category", "unknown")
        event = Event.new(id, slug, title, category)

        markets = node["markets"]?.try(&.as_a) || [] of JSON::Any
        event.markets = markets.map { |market_node| parse_market(market_node, event) }
        event
      end

      private def self.parse_market(node : JSON::Any, event : Event) : Market
        id = string(node, "id", "market-unknown")
        slug = string(node, "slug", id)
        question = string(node, "question", string(node, "title", slug))
        category = string(node, "category", event.category)
        end_time = optional_string(node, "endDate") || optional_string(node, "end_time")
        active = bool(node, "active", true)
        market = Market.new(id, event.id, slug, question, category, end_time, active)
        market.outcomes = parse_outcomes(node, market)
        market
      end

      private def self.parse_outcomes(node : JSON::Any, market : Market) : Array(Outcome)
        raw = node["outcomes"]?
        return [] of Outcome unless raw

        if object_outcomes = raw.as_a?
          first = object_outcomes.first?
          if first && first.as_h?
            return object_outcomes.map do |outcome_node|
              id = string(outcome_node, "id", string(outcome_node, "name", "outcome"))
              name = string(outcome_node, "name", id)
              yes = string(outcome_node, "yes_token_id", string(outcome_node, "token_id", id))
              no = optional_string(outcome_node, "no_token_id")
              p_hat = optional_fixed(outcome_node, "p_hat")
              confidence = optional_fixed(outcome_node, "confidence") || Fixed.parse("0.500000")
              stale_source = bool(outcome_node, "external_source_stale", false)
              Outcome.new(id, market.id, name, yes, no, p_hat, confidence, stale_source)
            end
          end
        end

        names = parse_string_list(raw) || [] of String
        token_ids = parse_string_list(node["clobTokenIds"]?) || parse_string_list(node["clob_token_ids"]?) || [] of String
        if names.size == 2 && names[0].downcase == "yes" && names[1].downcase == "no" && token_ids.size >= 2
          [Outcome.new(market.id, market.id, market.question, token_ids[0], token_ids[1], nil, Fixed.parse("0.500000"))]
        else
          names.each_with_index.map do |name, index|
            token = token_ids[index]? || "#{market.id}-#{name.downcase}"
            Outcome.new("#{market.id}-#{index}", market.id, name, token, nil, nil, Fixed.parse("0.500000"))
          end.to_a
        end
      end

      private def self.parse_string_list(node : JSON::Any?) : Array(String)?
        return nil unless node
        if arr = node.as_a?
          return arr.map { |item| item.as_s? || item.to_json }
        end
        if str = node.as_s?
          parsed = JSON.parse(str)
          return parsed.as_a.map { |item| item.as_s? || item.to_json }
        end
        nil
      end

      private def self.string(node : JSON::Any, key : String, default : String) : String
        optional_string(node, key) || default
      end

      private def self.optional_string(node : JSON::Any, key : String) : String?
        node[key]?.try { |value| value.as_s? || value.to_json }
      end

      private def self.bool(node : JSON::Any, key : String, default : Bool) : Bool
        node[key]?.try(&.as_bool) || default
      end

      private def self.optional_fixed(node : JSON::Any, key : String) : Fixed?
        value = node[key]?
        return nil unless value
        str = value.as_s?
        raise ArgumentError.new("fixed-point JSON value #{key} must be a string") unless str
        Fixed.parse(str)
      end
    end
  end
end
