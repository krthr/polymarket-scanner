require "json"
require "log"

module PolyScan
  module Clients
    class WebSocketScaffold
      getter enabled : Bool

      def initialize(@enabled : Bool = false)
      end

      def start : Nil
        log("ws_start") if @enabled
      end

      def heartbeat : Nil
        log("ws_heartbeat") if @enabled
      end

      def reconnect(reason : String) : Nil
        log("ws_reconnect", reason)
      end

      def resync(token_ids : Array(String)) : Nil
        log("ws_resync", token_ids.join(","))
      end

      private def log(event : String, detail : String? = nil) : Nil
        Log.info do
          JSON.build do |json|
            json.object do
              json.field "event", event
              json.field "read_only", true
              json.field "detail", detail if detail
            end
          end
        end
      end
    end
  end
end
