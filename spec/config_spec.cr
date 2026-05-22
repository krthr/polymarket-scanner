require "./spec_helper"

describe PolyScan::App::Config do
  it "rejects legacy fixture runtime configuration keys" do
    Dir.mkdir_p("tmp")
    path = "tmp/legacy_fixture_config.yml"
    File.write(path, %(data_source: "fixtures"\n))

    expect_raises(ArgumentError, /data_source is no longer supported/) do
      PolyScan::App::Config.load(path)
    end
  end

  it "rejects legacy fixture paths in production config" do
    Dir.mkdir_p("tmp")
    path = "tmp/legacy_fixture_paths.yml"
    File.write(path, %(gamma_fixture_path: "spec/fixtures/gamma_event.json"\n))

    expect_raises(ArgumentError, /gamma_fixture_path is no longer supported/) do
      PolyScan::App::Config.load(path)
    end
  end

  it "rejects the legacy data source environment override" do
    previous = ENV["POLY_SCAN_DATA_SOURCE"]?
    ENV["POLY_SCAN_DATA_SOURCE"] = "fixtures"

    begin
      expect_raises(ArgumentError, /POLY_SCAN_DATA_SOURCE is no longer supported/) do
        PolyScan::App::Config.load("missing-test-config.yml")
      end
    ensure
      if previous
        ENV["POLY_SCAN_DATA_SOURCE"] = previous
      else
        ENV.delete("POLY_SCAN_DATA_SOURCE")
      end
    end
  end
end
