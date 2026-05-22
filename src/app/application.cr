require "log"
require "./config"
require "./market_data_provider"
require "../alerts/telegram"
require "../clients/clob_client"
require "../clients/gamma_client"
require "../clients/http_client"
require "../clients/ws_scaffold"
require "../dashboard/server"
require "../detectors/runner"
require "../domain/order_book_cache"
require "../domain/relationships"
require "../paper/paper_trader"
require "../storage/store"

module PolyScan
  module App
    class Application
      getter config : Config
      getter events : Array(Event)
      getter markets : Array(Market)
      getter books : OrderBookCache
      getter graph : RelationshipGraph
      getter opportunities : Array(Opportunity)
      getter signals : Array(Signal)
      getter paper_trades : Array(Paper::PaperTrade)
      getter skipped_listings : Array(ListingSkip)

      def initialize(@config : Config, @events : Array(Event), @markets : Array(Market), @books : OrderBookCache, @graph : RelationshipGraph, @opportunities : Array(Opportunity), @signals : Array(Signal), @paper_trades : Array(Paper::PaperTrade), @skipped_listings : Array(ListingSkip), @store : Storage::Store)
      end

      def self.boot(config_path : String) : Application
        Log.setup(:info)
        config = Config.load(config_path)
        provider = real_provider(config)
        boot(config, provider)
      end

      def self.boot_with_provider(config_path : String, provider : MarketDataProvider) : Application
        Log.setup(:info)
        boot(Config.load(config_path), provider)
      end

      private def self.real_provider(config : Config) : MarketDataProvider
        gamma_http = Clients::HttpClient.from_config(config.gamma_base_url, config)
        clob_http = Clients::HttpClient.from_config(config.clob_base_url, config)
        RealPolymarketProvider.new(config, Clients::GammaClient.new(gamma_http), Clients::ClobClient.new(clob_http))
      end

      private def self.boot(config : Config, provider : MarketDataProvider) : Application
        Clients::WebSocketScaffold.new(false).start

        market_data = provider.load
        events = market_data.events
        markets = market_data.markets
        books = market_data.books
        graph = RelationshipGraph.load(config.relationships_path)

        detector_context = Detectors::Context.new(config, markets, books, graph)
        scan = Detectors::Runner.run(detector_context)
        paper_trades = Paper::PaperTrader.new(config.paper_trading_enabled).create_for(scan.opportunities)

        store = Storage::Store.new(config.database_path)
        store.save_events(events)
        store.save_rules(graph)
        store.save_books(books.all, scan.opportunities.empty? ? nil : "opportunity_scan")
        store.save_signals(scan.signals)
        store.save_paper_trades(paper_trades)

        alert = Alerts::TelegramAlert.new(config.telegram_enabled, config.telegram_bot_token, config.telegram_chat_id)
        scan.opportunities.each { |opportunity| alert.notify(opportunity) }

        new(config, events, markets, books, graph, scan.opportunities, scan.signals, paper_trades, market_data.skipped_listings, store)
      end

      def serve : Nil
        Dashboard::Server.new(@config, @markets, @books, @opportunities, @signals, @paper_trades).listen
      end

      def print_summary : Nil
        puts "events=#{@events.size} markets=#{@markets.size} books=#{@books.size} skipped_listings=#{@skipped_listings.size} rules=#{@graph.rules.size} opportunities=#{@opportunities.size} signals=#{@signals.size} paper_trades=#{@paper_trades.size}"
        @opportunities.each do |opp|
          puts "#{opp.id} status=#{opp.status} edge_net=#{opp.edge_net} score=#{opp.score}"
        end
      end
    end
  end
end
