require "./spec_helper"

private CONFIG_ENV_KEYS = %w(
  POLY_SCAN_BIND_HOST
  POLY_SCAN_PORT
  POLY_SCAN_DATABASE_PATH
  POLY_SCAN_RELATIONSHIPS_PATH
  POLY_SCAN_DATA_SOURCE
  POLY_SCAN_ALLOW_PUBLIC_BIND
  POLY_SCAN_TEST_TELEGRAM_TOKEN
  POLY_SCAN_TEST_TELEGRAM_CHAT
)

private def with_config_env(values = {} of String => String, &)
  previous = {} of String => String?
  CONFIG_ENV_KEYS.each do |key|
    previous[key] = ENV[key]?
    ENV.delete(key)
  end
  values.each { |key, value| ENV[key] = value }

  begin
    yield
  ensure
    previous.each do |key, value|
      if value
        ENV[key] = value
      else
        ENV.delete(key)
      end
    end
  end
end

private def with_config_file(contents : String, &)
  Dir.mkdir_p("tmp")
  path = "tmp/config_spec.yml"
  File.write(path, contents)

  begin
    yield path
  ensure
    FileUtils.rm_f(path)
  end
end

describe PolyScan::App::Config do
  it "loads defaults for a missing config file and applies environment overrides" do
    with_config_env({
      "POLY_SCAN_DATABASE_PATH"      => "tmp/env-config.db",
      "POLY_SCAN_RELATIONSHIPS_PATH" => "tmp/relationships.yml",
      "POLY_SCAN_DATA_SOURCE"        => "live",
    }) do
      config = PolyScan::App::Config.load("tmp/does-not-exist.yml")

      config.bind_host.should eq("127.0.0.1")
      config.port.should eq(8765)
      config.database_path.should eq("tmp/env-config.db")
      config.relationships_path.should eq("tmp/relationships.yml")
      config.data_source.should eq("live")
      config.http_timeout_ms.should eq(5_000)
      config.paper_trading_enabled.should be_true
      config.telegram_bot_token.should be_nil
      config.telegram_chat_id.should be_nil
    end
  end

  it "deserializes typed YAML sections and preserves flat compatibility accessors" do
    with_config_env({
      "POLY_SCAN_TEST_TELEGRAM_TOKEN" => "token-123",
      "POLY_SCAN_TEST_TELEGRAM_CHAT"  => "chat-456",
    }) do
      with_config_file(<<-YAML) do |path|
        bind_host: "127.0.0.1"
        port: 9876
        database_path: "tmp/config-spec.db"
        data_source: "fixtures"
        scan_size: "2.500000"
        max_spread: "0.070000"
        http:
          timeout_ms: 1234
          max_retries: 5
          retry_backoff_ms: 321
          retry_jitter_ms: 99
          rate_limit_per_minute: 30
        paper_trading:
          enabled: false
        telegram:
          enabled: true
          bot_token_env: "POLY_SCAN_TEST_TELEGRAM_TOKEN"
          chat_id_env: "POLY_SCAN_TEST_TELEGRAM_CHAT"
        YAML
        config = PolyScan::App::Config.load(path)

        config.port.should eq(9876)
        config.scan_size.should eq(fp("2.500000"))
        config.max_spread.should eq(fp("0.070000"))
        config.http_timeout_ms.should eq(1234)
        config.http_max_retries.should eq(5)
        config.http_retry_backoff_ms.should eq(321)
        config.http_retry_jitter_ms.should eq(99)
        config.http_rate_limit_per_minute.should eq(30)
        config.paper_trading_enabled.should be_false
        config.telegram_enabled.should be_true
        config.telegram_bot_token.should eq("token-123")
        config.telegram_chat_id.should eq("chat-456")
      end
    end
  end

  it "serializes fixed-point config values as quoted decimal strings" do
    yaml = PolyScan::App::Config.new.to_yaml

    yaml.should contain(%(scan_size: "1.000000"))
    yaml.should contain(%(max_spread: "0.080000"))
  end

  it "rejects unknown top-level YAML keys" do
    with_config_env do
      with_config_file(<<-YAML) do |path|
        bind_host: "127.0.0.1"
        typo_key: true
        YAML
        expect_raises(YAML::ParseException) do
          PolyScan::App::Config.load(path)
        end
      end
    end
  end

  it "rejects unknown nested YAML keys" do
    with_config_env do
      with_config_file(<<-YAML) do |path|
        http:
          timeout_ms: 5000
          typo_key: true
        YAML
        expect_raises(YAML::ParseException) do
          PolyScan::App::Config.load(path)
        end
      end
    end
  end

  it "rejects unquoted fixed-point YAML values" do
    with_config_env do
      with_config_file(<<-YAML) do |path|
        scan_size: 1.000000
        YAML
        error = expect_raises(YAML::ParseException) do
          PolyScan::App::Config.load(path)
        end
        error.message.to_s.should contain("quoted decimal string")
      end
    end
  end

  it "rejects invalid semantic values after deserialization and environment overrides" do
    with_config_env({"POLY_SCAN_DATA_SOURCE" => "invalid"}) do
      with_config_file(<<-YAML) do |path|
        data_source: "fixtures"
        http:
          rate_limit_per_minute: 60
        YAML
        expect_raises(ArgumentError, "data_source must be fixtures or live") do
          PolyScan::App::Config.load(path)
        end
      end
    end

    with_config_env do
      with_config_file(<<-YAML) do |path|
        http:
          rate_limit_per_minute: 0
        YAML
        expect_raises(ArgumentError, "rate_limit_per_minute must be positive") do
          PolyScan::App::Config.load(path)
        end
      end
    end
  end
end
