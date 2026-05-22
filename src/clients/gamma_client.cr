require "json"
require "./api_models"
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
        if root.as_h?.try { |hash| hash["events"]?.try(&.as_a?) }
          APIModels::GammaEventsEnvelope.from_json(body).to_domain
        elsif root.as_a?
          Array(APIModels::GammaEvent).from_json(body).map(&.to_domain)
        else
          [APIModels::GammaEvent.from_json(body).to_domain]
        end
      end
    end
  end
end
