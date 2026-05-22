require "file_utils"
require "micrate"
require "sqlite3"
require "../domain/models"
require "../domain/relationships"
require "../paper/paper_trader"

module PolyScan
  module Storage
    class Store
      getter path : String
      @db : DB::Database

      def initialize(@path : String)
        dir = File.dirname(@path)
        Dir.mkdir_p(dir) unless dir == "." || Dir.exists?(dir)
        run_migrations
        @db = ::DB.open(db_uri(@path))
      end

      def close : Nil
        @db.close
      end

      private def run_migrations : Nil
        Micrate::DB.connection_url = db_uri(@path)
        Micrate::DB.connect do |db|
          result = Micrate.up(db)
          raise "database migration failed" if result == :error
        end
      end

      def save_events(events : Array(Event)) : Nil
        now = Time.utc.to_unix_ms
        events.each do |event|
          @db.exec(
            "insert or replace into events (id, slug, title, category, raw_json, updated_at_unix_ms) values (?, ?, ?, ?, ?, ?)",
            event.id, event.slug, event.title, event.category, event.to_json, now
          )
          event.markets.each do |market|
            save_market(market, now)
          end
        end
      end

      def save_rules(graph : RelationshipGraph) : Nil
        now = Time.utc.to_unix_ms
        graph.rules.each do |rule|
          @db.exec(
            "insert or replace into relationship_rules (id, type, raw_json, updated_at_unix_ms) values (?, ?, ?, ?)",
            rule.id, rule.type, rule.to_json, now
          )
        end
      end

      def save_books(books : Array(OrderBook), snapshot_reason : String? = nil) : Nil
        now = Time.utc.to_unix_ms
        books.each do |book|
          bid = book.top_bid
          ask = book.top_ask
          @db.exec(
            "insert or replace into book_top (token_id, market_id, bid_price_atoms, bid_size_atoms, ask_price_atoms, ask_size_atoms, fetched_at_unix_ms, updated_at_unix_ms) values (?, ?, ?, ?, ?, ?, ?, ?)",
            book.token_id,
            book.market_id,
            bid.try(&.price.atoms),
            bid.try(&.size.atoms),
            ask.try(&.price.atoms),
            ask.try(&.size.atoms),
            book.fetched_at_unix_ms,
            now
          )
          if reason = snapshot_reason
            @db.exec(
              "insert into book_snapshots (token_id, market_id, raw_json, reason, fetched_at_unix_ms, created_at_unix_ms) values (?, ?, ?, ?, ?, ?)",
              book.token_id, book.market_id, book.to_json, reason, book.fetched_at_unix_ms, now
            )
          end
        end
      end

      def save_signals(signals : Array(Signal)) : Nil
        signals.each do |signal|
          @db.exec(
            "insert or replace into signals (id, detector, market_id, status, edge_net_atoms, score_atoms, confidence_atoms, raw_json, created_at_unix_ms) values (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            signal.id,
            signal.detector,
            signal.market_id,
            signal.status.to_s,
            signal.edge_net.atoms,
            signal.score.atoms,
            signal.confidence.atoms,
            signal.to_json,
            signal.created_at_unix_ms
          )
        end
      end

      def save_paper_trades(trades : Array(Paper::PaperTrade)) : Nil
        trades.each do |trade|
          @db.exec(
            "insert or replace into paper_trades (id, opportunity_id, status, total_cost_atoms, expected_payout_atoms, raw_json, created_at_unix_ms) values (?, ?, ?, ?, ?, ?, ?)",
            trade.id,
            trade.opportunity_id,
            trade.status,
            trade.total_cost.atoms,
            trade.expected_payout.atoms,
            trade.to_json,
            trade.created_at_unix_ms
          )
        end
      end

      private def save_market(market : Market, now : Int64) : Nil
        @db.exec(
          "insert or replace into markets (id, event_id, slug, question, category, end_time, active, raw_json, updated_at_unix_ms) values (?, ?, ?, ?, ?, ?, ?, ?, ?)",
          market.id, market.event_id, market.slug, market.question, market.category, market.end_time, market.active ? 1 : 0, market.to_json, now
        )
        market.outcomes.each do |outcome|
          @db.exec(
            "insert or replace into outcomes (id, market_id, name, yes_token_id, no_token_id, p_hat_atoms, confidence_atoms, raw_json, updated_at_unix_ms) values (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            outcome.id,
            outcome.market_id,
            outcome.name,
            outcome.yes_token_id,
            outcome.no_token_id,
            outcome.p_hat.try(&.atoms),
            outcome.confidence.atoms,
            outcome.to_json,
            now
          )
        end
      end

      private def db_uri(path : String) : String
        path.starts_with?("/") ? "sqlite3://#{path}" : "sqlite3://./#{path}"
      end
    end
  end
end
