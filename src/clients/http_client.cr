require "http/client"
require "json"
require "log"
require "uri"
require "../app/config"

module PolyScan
  module Clients
    class HttpClient
      getter base_url : String

      def initialize(@base_url : String, @timeout_ms : Int32, @max_retries : Int32, @retry_backoff_ms : Int32, @retry_jitter_ms : Int32, @rate_limit_per_minute : Int32)
        @last_request_ms = 0_i64
      end

      def self.from_config(base_url : String, config : App::Config) : HttpClient
        new(
          base_url: base_url,
          timeout_ms: config.http_timeout_ms,
          max_retries: config.http_max_retries,
          retry_backoff_ms: config.http_retry_backoff_ms,
          retry_jitter_ms: config.http_retry_jitter_ms,
          rate_limit_per_minute: config.http_rate_limit_per_minute
        )
      end

      def get(path : String) : String
        attempts = 0
        loop do
          attempts += 1
          throttle
          uri = uri_for(path)
          started_ms = Time.utc.to_unix_ms

          begin
            response = execute_get(uri)
            elapsed_ms = Time.utc.to_unix_ms - started_ms
            log_http("http_response", uri, response.status_code, elapsed_ms, attempts)
            if response.status_code >= 200 && response.status_code < 300
              return response.body
            end
            raise "HTTP #{response.status_code}"
          rescue ex
            elapsed_ms = Time.utc.to_unix_ms - started_ms
            log_http("http_error", uri, 0, elapsed_ms, attempts, ex.message)
            raise ex if attempts > @max_retries + 1
            sleep backoff_for(attempts)
          end
        end
      end

      def get_json(path : String) : JSON::Any
        JSON.parse(get(path))
      end

      private def uri_for(path : String) : URI
        if path.starts_with?("http://") || path.starts_with?("https://")
          URI.parse(path)
        else
          URI.parse("#{@base_url}#{path}")
        end
      end

      private def execute_get(uri : URI) : HTTP::Client::Response
        HTTP::Client.new(uri) do |client|
          timeout = @timeout_ms.milliseconds
          client.connect_timeout = timeout
          client.read_timeout = timeout
          client.write_timeout = timeout
          headers = HTTP::Headers{"Accept" => "application/json", "User-Agent" => "poly-scan-readonly/0.1"}
          client.get(uri.request_target, headers: headers)
        end
      end

      private def throttle : Nil
        min_interval_ms = 60_000_i64 // @rate_limit_per_minute
        now_ms = Time.utc.to_unix_ms
        elapsed_ms = now_ms - @last_request_ms
        sleep((min_interval_ms - elapsed_ms).milliseconds) if @last_request_ms > 0 && elapsed_ms < min_interval_ms
        @last_request_ms = Time.utc.to_unix_ms
      end

      private def backoff_for(attempt : Int32) : Time::Span
        multiplier = 1_i64 << (attempt - 1)
        jitter = @retry_jitter_ms > 0 ? Random.rand(@retry_jitter_ms + 1) : 0
        (@retry_backoff_ms.to_i64 * multiplier + jitter).milliseconds
      end

      private def log_http(event : String, uri : URI, status_code : Int32, elapsed_ms : Int64, attempt : Int32, error : String? = nil) : Nil
        Log.info do
          JSON.build do |json|
            json.object do
              json.field "event", event
              json.field "method", "GET"
              json.field "url", uri.to_s
              json.field "status_code", status_code
              json.field "elapsed_ms", elapsed_ms
              json.field "attempt", attempt
              json.field "error", error if error
            end
          end
        end
      end
    end
  end
end
