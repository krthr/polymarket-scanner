require "./spec_helper"

describe "fixture scanner integration" do
  it "generates a logical-bundle opportunity and a paper trade" do
    Dir.mkdir_p("tmp")
    FileUtils.rm_f("tmp/spec_poly_scan.db")
    previous_db = ENV["POLY_SCAN_DATABASE_PATH"]?
    ENV["POLY_SCAN_DATABASE_PATH"] = "tmp/spec_poly_scan.db"

    begin
      provider = PolyScan::App::FixtureMarketDataProvider.new("spec/fixtures/gamma_event.json", "spec/fixtures/books")
      app = PolyScan::App::Application.boot_with_provider("config/app.example.yml", provider)
      implication = app.opportunities.find { |opp| opp.detector == "Implication" }
      implication.should_not be_nil
      implication.not_nil!.edge_net.should be > fp("0")
      implication.not_nil!.legs.size.should eq(2)

      app.paper_trades.size.should eq(1)
      app.paper_trades.first.opportunity_id.should eq(implication.not_nil!.id)
      File.exists?("tmp/spec_poly_scan.db").should be_true

      DB.open("sqlite3://./tmp/spec_poly_scan.db") do |db|
        tables = db.query_all("select name from sqlite_master where type = 'table'", as: String)
        %w(events markets outcomes book_top book_snapshots relationship_rules signals paper_trades alerts micrate_db_version).each do |table|
          tables.should contain(table)
        end

        market_columns = db.query_all("pragma table_info(markets)", as: {Int64, String, String, Int64, String?, Int64}).map { |row| row[1] }
        %w(gamma_id condition_id question_id closed archived accepting_orders).each do |column|
          market_columns.should contain(column)
        end

        applied_migrations = db.query_one("select count(*) from micrate_db_version where is_applied = 1", as: Int64)
        applied_migrations.should eq(10)
      end
    ensure
      if previous_db
        ENV["POLY_SCAN_DATABASE_PATH"] = previous_db
      else
        ENV.delete("POLY_SCAN_DATABASE_PATH")
      end
    end
  end
end
