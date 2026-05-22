require "json"
require "uri"
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

      def fetch_market_events(max_markets : Int32) : Array(Event)
        events_by_id = {} of String => Event
        cursor : String? = nil
        fetched = 0

        while fetched < max_markets
          page_limit = {max_markets - fetched, 100}.min
          path = "/markets?limit=#{page_limit}&closed=false"
          if current_cursor = cursor
            path += "&cursor=#{URI.encode_path_segment(current_cursor)}"
          end

          page = JSON.parse(@http.get(path))
          page_events, next_cursor = self.class.parse_market_listing_page(page)
          page_market_count = page_events.sum { |event| event.markets.size }
          break if page_market_count == 0

          merge_events(events_by_id, page_events)
          fetched += page_market_count

          cursor = next_cursor
          break if cursor.nil? || cursor == ""
        end

        events_by_id.values
      end

      def self.events_from_file(path : String) : Array(Event)
        parse_events(File.read(path))
      end

      def self.parse_events(body : String) : Array(Event)
        root = JSON.parse(body)
        event_nodes = root.as_h?.try { |hash| hash["events"]?.try(&.as_a) } || root.as_a? || [root]
        event_nodes.map { |node| parse_event(node) }
      end

      def self.parse_market_listing_page(root : JSON::Any) : Tuple(Array(Event), String?)
        root_hash = root.as_h?
        market_nodes = root_hash.try { |hash| hash["markets"]?.try(&.as_a) } || root.as_a? || [] of JSON::Any
        events_by_id = {} of String => Event

        market_nodes.each do |market_node|
          event = event_for_market_listing(market_node)
          stored_event = events_by_id[event.id]?
          unless stored_event
            stored_event = Event.new(event.id, event.slug, event.title, event.category)
            events_by_id[event.id] = stored_event
          end
          stored_event.markets << parse_market(market_node, stored_event, allow_token_fallback: false)
        end

        next_cursor = root_hash.try { |hash| hash["next_cursor"]?.try(&.as_s?) }
        {events_by_id.values, next_cursor}
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

      private def self.event_for_market_listing(node : JSON::Any) : Event
        nested = node["events"]?.try(&.as_a.first?)
        return parse_event_metadata(nested) if nested

        id = string(node, "id", string(node, "conditionId", string(node, "condition_id", "market-unknown")))
        slug = string(node, "slug", id)
        title = string(node, "question", string(node, "title", slug))
        category = string(node, "category", "unknown")
        Event.new("market-#{id}", slug, title, category)
      end

      private def self.parse_event_metadata(node : JSON::Any) : Event
        id = string(node, "id", "event-unknown")
        slug = string(node, "slug", string(node, "ticker", id))
        title = string(node, "title", string(node, "name", slug))
        category = string(node, "category", "unknown")
        Event.new(id, slug, title, category)
      end

      private def self.parse_market(node : JSON::Any, event : Event, allow_token_fallback : Bool = true) : Market
        gamma_id = optional_string(node, "id")
        condition_id = optional_string(node, "conditionId") || optional_string(node, "condition_id")
        question_id = optional_string(node, "questionID") || optional_string(node, "questionId") || optional_string(node, "question_id")
        id = condition_id || gamma_id || string(node, "slug", "market-unknown")
        slug = string(node, "slug", id)
        question = string(node, "question", string(node, "title", slug))
        category = string(node, "category", event.category)
        end_time = optional_string(node, "endDate") || optional_string(node, "end_time")
        active = bool(node, "active", true)
        closed = bool(node, "closed", false)
        archived = bool(node, "archived", false)
        accepting_orders = bool(node, "acceptingOrders", bool(node, "accepting_orders", true))
        market = Market.new(
          id: id,
          event_id: event.id,
          slug: slug,
          question: question,
          category: category,
          end_time: end_time,
          active: active,
          gamma_id: gamma_id,
          condition_id: condition_id,
          question_id: question_id,
          closed: closed,
          archived: archived,
          accepting_orders: accepting_orders
        )
        market.outcomes = parse_outcomes(node, market, allow_token_fallback)
        market
      end

      private def self.parse_outcomes(node : JSON::Any, market : Market, allow_token_fallback : Bool = true) : Array(Outcome)
        raw = node["outcomes"]?
        return [] of Outcome unless raw

        if object_outcomes = raw.as_a?
          first = object_outcomes.first?
          if first && first.as_h?
            return object_outcomes.compact_map do |outcome_node|
              id = string(outcome_node, "id", string(outcome_node, "name", "outcome"))
              name = string(outcome_node, "name", id)
              yes = optional_string(outcome_node, "yes_token_id") || optional_string(outcome_node, "token_id")
              next unless yes || allow_token_fallback
              yes ||= id
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
          names.each_with_index.compact_map do |name, index|
            token = token_ids[index]?
            next unless token || allow_token_fallback
            token ||= "#{market.id}-#{name.downcase}"
            Outcome.new("#{market.id}-#{index}", market.id, name, token, nil, nil, Fixed.parse("0.500000"))
          end.to_a
        end
      end

      private def merge_events(events_by_id : Hash(String, Event), events : Array(Event)) : Nil
        events.each do |event|
          stored_event = events_by_id[event.id]?
          unless stored_event
            stored_event = Event.new(event.id, event.slug, event.title, event.category)
            events_by_id[event.id] = stored_event
          end
          event.markets.each { |market| stored_event.markets << market }
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
        value = node[key]?
        value ? value.as_bool : default
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
