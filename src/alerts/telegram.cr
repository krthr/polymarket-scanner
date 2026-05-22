require "json"
require "log"
require "../domain/models"

module PolyScan
  module Alerts
    class TelegramAlert
      def initialize(@enabled : Bool, @bot_token : String?, @chat_id : String?)
      end

      def notify(opportunity : Opportunity) : Nil
        unless @enabled
          log("telegram_skipped", opportunity.id, "disabled")
          return
        end

        if @bot_token.nil? || @chat_id.nil?
          log("telegram_skipped", opportunity.id, "missing_credentials")
          return
        end

        log("telegram_ready", opportunity.id, "scaffold_only_no_network_send")
      end

      private def log(event : String, opportunity_id : String, status : String) : Nil
        Log.info do
          JSON.build do |json|
            json.object do
              json.field "event", event
              json.field "channel", "telegram"
              json.field "opportunity_id", opportunity_id
              json.field "status", status
            end
          end
        end
      end
    end
  end
end
