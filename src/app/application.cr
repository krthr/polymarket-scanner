require "log"
require "./config"
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

      def initialize(@config : Config, @events : Array(Event), @markets : Array(Market), @books : OrderBookCache, @graph : RelationshipGraph, @opportunities : Array(Opportunity), @signals : Array(Signal), @paper_trades : Array(Paper::PaperTrade), @store : Storage::Store)
      end

      def self.boot(config_path : String) : Application
        Log.setup(:info)
        config = Config.load(config_path)

        gamma_http = Clients::HttpClient.from_config(config.gamma_base_url, config)
        clob_http = Clients::HttpClient.from_config(config.clob_base_url, config)
        Clients::GammaClient.new(gamma_http)
        clob_client = Clients::ClobClient.new(clob_http)
        Clients::WebSocketScaffold.new(false).start

        events, markets, books = load_market_data(config, clob_client)
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

        new(config, events, markets, books, graph, scan.opportunities, scan.signals, paper_trades, store)
      end

      private def self.load_market_data(config : Config, clob_client : Clients::ClobClient) : Tuple(Array(Event), Array(Market), OrderBookCache)
        case config.data_source
        when "live"
          load_live_market_data(config, clob_client)
        else
          load_fixture_market_data(config)
        end
      end

      private def self.load_fixture_market_data(config : Config) : Tuple(Array(Event), Array(Market), OrderBookCache)
        events = Clients::GammaClient.events_from_file(config.gamma_fixture_path)
        markets = events.flat_map(&.markets)
        books = OrderBookCache.new
        Clients::ClobClient.books_from_dir(config.clob_books_path).each { |book| books.put(book) }
        {events, markets, books}
      end

      private def self.load_live_market_data(config : Config, clob_client : Clients::ClobClient) : Tuple(Array(Event), Array(Market), OrderBookCache)
        markets = clob_client.fetch_sampling_markets(config.live_market_limit)
        event = Event.new("clob-live", "clob-live", "Live CLOB markets", "live", markets)
        books = OrderBookCache.new

        live_token_ids(markets).first(config.live_book_limit).each do |token_id|
          begin
            books.put(clob_client.fetch_book(token_id))
          rescue ex
            Log.warn { %({"event":"live_book_fetch_failed","token_id":#{token_id.to_json},"error":#{ex.message.to_json}}) }
          end
        end

        {[event], markets, books}
      end

      private def self.live_token_ids(markets : Array(Market)) : Array(String)
        markets.flat_map do |market|
          market.outcomes.flat_map do |outcome|
            ids = [outcome.yes_token_id]
            if no_token_id = outcome.no_token_id
              ids << no_token_id
            end
            ids
          end
        end.uniq
      end

      def serve : Nil
        Dashboard::Server.new(@config, @markets, @books, @opportunities, @signals, @paper_trades).listen
      end

      def print_summary : Nil
        puts "events=#{@events.size} markets=#{@markets.size} books=#{@books.size} rules=#{@graph.rules.size} opportunities=#{@opportunities.size} signals=#{@signals.size} paper_trades=#{@paper_trades.size}"
        @opportunities.each do |opp|
          puts "#{opp.id} status=#{opp.status} edge_net=#{opp.edge_net} score=#{opp.score}"
        end
      end
    end
  end
end
