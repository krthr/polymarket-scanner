require "yaml"
require "../domain/fixed"

module PolyScan
  module App
    class Config
      property bind_host : String = "127.0.0.1"
      property port : Int32 = 8765
      property database_path : String = "data/poly_scan.db"
      property gamma_base_url : String = "https://gamma-api.polymarket.com"
      property clob_base_url : String = "https://clob.polymarket.com"
      property data_source : String = "fixtures"
      property gamma_fixture_path : String = "spec/fixtures/gamma_event.json"
      property clob_books_path : String = "spec/fixtures/books"
      property relationships_path : String = "config/relationships.example.yml"
      property live_market_limit : Int32 = 25
      property live_book_limit : Int32 = 50

      property scan_size : Fixed = Fixed.one
      property taker_fee_bps : Int32 = 0
      property max_book_age_ms : Int64 = 300_000_i64
      property max_spread : Fixed = Fixed.parse("0.080000")
      property min_depth : Fixed = Fixed.parse("1.000000")
      property slippage_buffer : Fixed = Fixed.parse("0.005000")
      property uncertainty_penalty : Fixed = Fixed.parse("0.003000")
      property resolution_penalty : Fixed = Fixed.parse("0.002000")
      property stale_book_penalty : Fixed = Fixed.parse("0.010000")
      property low_confidence_threshold : Fixed = Fixed.parse("0.600000")
      property high_fee_threshold : Fixed = Fixed.parse("0.010000")
      property imbalance_ratio : Fixed = Fixed.parse("3.000000")

      property http_timeout_ms : Int32 = 5_000
      property http_max_retries : Int32 = 2
      property http_retry_backoff_ms : Int32 = 250
      property http_retry_jitter_ms : Int32 = 125
      property http_rate_limit_per_minute : Int32 = 60

      property paper_trading_enabled : Bool = true
      property telegram_enabled : Bool = false
      property telegram_bot_token : String? = nil
      property telegram_chat_id : String? = nil

      def self.load(path : String) : Config
        config = new
        if File.exists?(path)
          doc = YAML.parse(File.read(path))
          config.bind_host = string(doc, "bind_host", config.bind_host)
          config.port = int32(doc, "port", config.port)
          config.database_path = string(doc, "database_path", config.database_path)
          config.gamma_base_url = string(doc, "gamma_base_url", config.gamma_base_url)
          config.clob_base_url = string(doc, "clob_base_url", config.clob_base_url)
          config.data_source = string(doc, "data_source", config.data_source)
          config.gamma_fixture_path = string(doc, "gamma_fixture_path", config.gamma_fixture_path)
          config.clob_books_path = string(doc, "clob_books_path", config.clob_books_path)
          config.relationships_path = string(doc, "relationships_path", config.relationships_path)
          config.live_market_limit = int32(doc, "live_market_limit", config.live_market_limit)
          config.live_book_limit = int32(doc, "live_book_limit", config.live_book_limit)

          config.scan_size = fixed(doc, "scan_size", config.scan_size)
          config.taker_fee_bps = int32(doc, "taker_fee_bps", config.taker_fee_bps)
          config.max_book_age_ms = int64(doc, "max_book_age_ms", config.max_book_age_ms)
          config.max_spread = fixed(doc, "max_spread", config.max_spread)
          config.min_depth = fixed(doc, "min_depth", config.min_depth)
          config.slippage_buffer = fixed(doc, "slippage_buffer", config.slippage_buffer)
          config.uncertainty_penalty = fixed(doc, "uncertainty_penalty", config.uncertainty_penalty)
          config.resolution_penalty = fixed(doc, "resolution_penalty", config.resolution_penalty)
          config.stale_book_penalty = fixed(doc, "stale_book_penalty", config.stale_book_penalty)
          config.low_confidence_threshold = fixed(doc, "low_confidence_threshold", config.low_confidence_threshold)
          config.high_fee_threshold = fixed(doc, "high_fee_threshold", config.high_fee_threshold)
          config.imbalance_ratio = fixed(doc, "imbalance_ratio", config.imbalance_ratio)

          if http = doc["http"]?
            config.http_timeout_ms = int32(http, "timeout_ms", config.http_timeout_ms)
            config.http_max_retries = int32(http, "max_retries", config.http_max_retries)
            config.http_retry_backoff_ms = int32(http, "retry_backoff_ms", config.http_retry_backoff_ms)
            config.http_retry_jitter_ms = int32(http, "retry_jitter_ms", config.http_retry_jitter_ms)
            config.http_rate_limit_per_minute = int32(http, "rate_limit_per_minute", config.http_rate_limit_per_minute)
          end

          if paper = doc["paper_trading"]?
            config.paper_trading_enabled = bool(paper, "enabled", config.paper_trading_enabled)
          end

          if telegram = doc["telegram"]?
            config.telegram_enabled = bool(telegram, "enabled", config.telegram_enabled)
            config.telegram_bot_token = optional_string(telegram, "bot_token_env").try { |env_name| ENV[env_name]? }
            config.telegram_chat_id = optional_string(telegram, "chat_id_env").try { |env_name| ENV[env_name]? }
          end
        end

        config.apply_env!
        config.validate!
        config
      end

      def apply_env! : Nil
        @bind_host = ENV["POLY_SCAN_BIND_HOST"]? || @bind_host
        @port = ENV["POLY_SCAN_PORT"]?.try(&.to_i32) || @port
        @database_path = ENV["POLY_SCAN_DATABASE_PATH"]? || @database_path
        @relationships_path = ENV["POLY_SCAN_RELATIONSHIPS_PATH"]? || @relationships_path
        @data_source = ENV["POLY_SCAN_DATA_SOURCE"]? || @data_source
      end

      def validate! : Nil
        if @bind_host != "127.0.0.1" && ENV["POLY_SCAN_ALLOW_PUBLIC_BIND"]? != "true"
          raise ArgumentError.new("refusing to bind #{@bind_host}; set POLY_SCAN_ALLOW_PUBLIC_BIND=true only if you understand the risk")
        end
        unless {"fixtures", "live"}.includes?(@data_source)
          raise ArgumentError.new("data_source must be fixtures or live")
        end
        raise ArgumentError.new("scan_size must be positive") unless @scan_size.positive?
        raise ArgumentError.new("rate_limit_per_minute must be positive") unless @http_rate_limit_per_minute > 0
        raise ArgumentError.new("live_market_limit must be positive") unless @live_market_limit > 0
        raise ArgumentError.new("live_book_limit must be positive") unless @live_book_limit > 0
      end

      private def self.string(node : YAML::Any, key : String, default : String) : String
        node[key]?.try(&.as_s) || default
      end

      private def self.optional_string(node : YAML::Any, key : String) : String?
        node[key]?.try(&.as_s)
      end

      private def self.int32(node : YAML::Any, key : String, default : Int32) : Int32
        node[key]?.try(&.as_i.to_i32) || default
      end

      private def self.int64(node : YAML::Any, key : String, default : Int64) : Int64
        node[key]?.try(&.as_i64) || default
      end

      private def self.bool(node : YAML::Any, key : String, default : Bool) : Bool
        value = node[key]?
        value ? value.as_bool : default
      end

      private def self.fixed(node : YAML::Any, key : String, default : Fixed) : Fixed
        value = node[key]?
        return default unless value

        str = value.as_s?
        raise ArgumentError.new("fixed-point config value #{key} must be a quoted decimal string") unless str
        Fixed.parse(str)
      end
    end
  end
end
