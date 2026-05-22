require "yaml"
require "../domain/fixed"

module PolyScan
  module App
    class HttpConfig
      include YAML::Serializable
      include YAML::Serializable::Strict

      property timeout_ms : Int32 = 5_000
      property max_retries : Int32 = 2
      property retry_backoff_ms : Int32 = 250
      property retry_jitter_ms : Int32 = 125
      property rate_limit_per_minute : Int32 = 60

      def initialize
      end
    end

    class PaperTradingConfig
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = true

      def initialize
      end
    end

    class TelegramConfig
      include YAML::Serializable
      include YAML::Serializable::Strict

      property enabled : Bool = false
      property bot_token_env : String? = nil
      property chat_id_env : String? = nil

      def initialize
      end
    end

    class Config
      include YAML::Serializable
      include YAML::Serializable::Strict

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

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property scan_size : Fixed = Fixed.one

      property taker_fee_bps : Int32 = 0
      property max_book_age_ms : Int64 = 300_000_i64

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property max_spread : Fixed = Fixed.parse("0.080000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property min_depth : Fixed = Fixed.parse("1.000000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property slippage_buffer : Fixed = Fixed.parse("0.005000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property uncertainty_penalty : Fixed = Fixed.parse("0.003000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property resolution_penalty : Fixed = Fixed.parse("0.002000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property stale_book_penalty : Fixed = Fixed.parse("0.010000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property low_confidence_threshold : Fixed = Fixed.parse("0.600000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property high_fee_threshold : Fixed = Fixed.parse("0.010000")

      @[YAML::Field(converter: ::PolyScan::Fixed::YAMLConverter)]
      property imbalance_ratio : Fixed = Fixed.parse("3.000000")

      property http : HttpConfig = HttpConfig.new
      property paper_trading : PaperTradingConfig = PaperTradingConfig.new
      property telegram : TelegramConfig = TelegramConfig.new

      @[YAML::Field(ignore: true)]
      property telegram_bot_token : String? = nil

      @[YAML::Field(ignore: true)]
      property telegram_chat_id : String? = nil

      def initialize
      end

      def self.load(path : String) : Config
        config = File.exists?(path) ? from_yaml(File.read(path)) : new
        config.resolve_secrets!
        config.apply_env!
        config.validate!
        config
      end

      def http_timeout_ms : Int32
        @http.timeout_ms
      end

      def http_timeout_ms=(value : Int32) : Int32
        @http.timeout_ms = value
      end

      def http_max_retries : Int32
        @http.max_retries
      end

      def http_max_retries=(value : Int32) : Int32
        @http.max_retries = value
      end

      def http_retry_backoff_ms : Int32
        @http.retry_backoff_ms
      end

      def http_retry_backoff_ms=(value : Int32) : Int32
        @http.retry_backoff_ms = value
      end

      def http_retry_jitter_ms : Int32
        @http.retry_jitter_ms
      end

      def http_retry_jitter_ms=(value : Int32) : Int32
        @http.retry_jitter_ms = value
      end

      def http_rate_limit_per_minute : Int32
        @http.rate_limit_per_minute
      end

      def http_rate_limit_per_minute=(value : Int32) : Int32
        @http.rate_limit_per_minute = value
      end

      def paper_trading_enabled : Bool
        @paper_trading.enabled
      end

      def paper_trading_enabled=(value : Bool) : Bool
        @paper_trading.enabled = value
      end

      def telegram_enabled : Bool
        @telegram.enabled
      end

      def telegram_enabled=(value : Bool) : Bool
        @telegram.enabled = value
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
        raise ArgumentError.new("rate_limit_per_minute must be positive") unless http_rate_limit_per_minute > 0
        raise ArgumentError.new("live_market_limit must be positive") unless @live_market_limit > 0
        raise ArgumentError.new("live_book_limit must be positive") unless @live_book_limit > 0
      end

      def resolve_secrets! : Nil
        @telegram_bot_token = @telegram.bot_token_env.try { |env_name| ENV[env_name]? }
        @telegram_chat_id = @telegram.chat_id_env.try { |env_name| ENV[env_name]? }
      end
    end
  end
end
