require "./spec_helper"

describe "fixture scanner integration" do
  it "generates a logical-bundle opportunity and a paper trade" do
    Dir.mkdir_p("tmp")
    FileUtils.rm_f("tmp/spec_poly_scan.db")
    previous_db = ENV["POLY_SCAN_DATABASE_PATH"]?
    ENV["POLY_SCAN_DATABASE_PATH"] = "tmp/spec_poly_scan.db"

    begin
      app = PolyScan::App::Application.boot("config/app.example.yml")
      implication = app.opportunities.find { |opp| opp.detector == "Implication" }
      implication.should_not be_nil
      implication.not_nil!.edge_net.should be > fp("0")
      implication.not_nil!.legs.size.should eq(2)

      app.paper_trades.size.should eq(1)
      app.paper_trades.first.opportunity_id.should eq(implication.not_nil!.id)
      File.exists?("tmp/spec_poly_scan.db").should be_true
    ensure
      if previous_db
        ENV["POLY_SCAN_DATABASE_PATH"] = previous_db
      else
        ENV.delete("POLY_SCAN_DATABASE_PATH")
      end
    end
  end
end
