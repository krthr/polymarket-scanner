require "http/server"
require "json"
require "../app/config"
require "../domain/models"
require "../domain/order_book_cache"
require "../paper/paper_trader"

module PolyScan
  module Dashboard
    class Server
      def initialize(@config : App::Config, @markets : Array(Market), @books : OrderBookCache, @opportunities : Array(Opportunity), @signals : Array(Signal), @paper_trades : Array(Paper::PaperTrade))
      end

      def listen : Nil
        server = HTTP::Server.new do |context|
          route(context)
        end

        address = server.bind_tcp(@config.bind_host, @config.port)
        puts "poly-scan dashboard listening on http://#{address}"
        server.listen
      end

      private def route(context : HTTP::Server::Context) : Nil
        request = context.request
        path = request.path
        context.response.headers["Cache-Control"] = "no-store"

        case
        when request.method != "GET"
          json(context, 405) { |j| j.field "error", "method_not_allowed" }
        when path == "/" || path == "/opportunities"
          html(context, opportunities_html)
        when path == "/api/health"
          json(context) do |j|
            j.field "ok", true
            j.field "read_only", true
            j.field "order_placement_enabled", false
            j.field "wallet_configured", false
            j.field "bind_host", @config.bind_host
            j.field "market_count", @markets.size
            j.field "book_count", @books.size
            j.field "opportunity_count", @opportunities.size
          end
        when path == "/api/markets"
          array_json(context, @markets)
        when path.starts_with?("/api/books/")
          token_id = path.sub("/api/books/", "")
          if book = @books.get(token_id)
            object_json(context, book)
          else
            json(context, 404) { |j| j.field "error", "book_not_found" }
          end
        when path == "/api/opportunities"
          array_json(context, @opportunities)
        when path.starts_with?("/api/opportunities/")
          id = path.sub("/api/opportunities/", "")
          if opportunity = @opportunities.find { |opp| opp.id == id }
            object_json(context, opportunity)
          else
            json(context, 404) { |j| j.field "error", "opportunity_not_found" }
          end
        when path == "/api/signals"
          array_json(context, @signals)
        when path == "/api/paper-trades"
          array_json(context, @paper_trades)
        when path == "/api/metrics"
          json(context) do |j|
            j.field "events", event_count
            j.field "markets", @markets.size
            j.field "outcomes", @markets.sum { |m| m.outcomes.size }
            j.field "books", @books.size
            j.field "opportunities", @opportunities.size
            j.field "signals", @signals.size
            j.field "paper_trades", @paper_trades.size
            j.field "read_only", true
          end
        else
          json(context, 404) { |j| j.field "error", "not_found" }
        end
      end

      private def event_count : Int32
        @markets.map(&.event_id).uniq.size
      end

      private def html(context : HTTP::Server::Context, body : String) : Nil
        context.response.content_type = "text/html; charset=utf-8"
        context.response.print(body)
      end

      private def object_json(context : HTTP::Server::Context, object) : Nil
        context.response.content_type = "application/json"
        object.to_json(context.response)
      end

      private def array_json(context : HTTP::Server::Context, objects) : Nil
        context.response.content_type = "application/json"
        objects.to_json(context.response)
      end

      private def json(context : HTTP::Server::Context, status : Int32 = 200, &) : Nil
        context.response.status_code = status
        context.response.content_type = "application/json"
        JSON.build(context.response) do |j|
          j.object do
            yield j
          end
        end
      end

      private def opportunities_html : String
        rows = @opportunities.map do |opp|
          <<-ROW
          <tr>
            <td><a href="/api/opportunities/#{escape(opp.id)}">#{escape(opp.id)}</a></td>
            <td>#{escape(opp.detector)}</td>
            <td>#{escape(opp.status.to_s)}</td>
            <td>#{escape(opp.edge_net.to_s)}</td>
            <td>#{escape(opp.score.to_s)}</td>
            <td>#{escape(opp.risk_flags.join(", "))}</td>
          </tr>
          ROW
        end.join("\n")

        <<-HTML
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Polymarket Inefficiency Scanner</title>
          <style>
            :root { color-scheme: light; font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
            body { margin: 0; background: #f7f8fa; color: #171a1f; }
            main { max-width: 1120px; margin: 0 auto; padding: 28px 18px 48px; }
            header { display: flex; align-items: baseline; justify-content: space-between; gap: 16px; margin-bottom: 22px; }
            h1 { font-size: 24px; line-height: 1.2; margin: 0; }
            .meta { color: #5d6673; font-size: 13px; }
            table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid #d8dde6; }
            th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid #e6e9ef; font-size: 13px; vertical-align: top; }
            th { background: #eef1f6; color: #303642; font-weight: 650; }
            a { color: #0958d9; text-decoration: none; }
            .empty { background: #fff; border: 1px solid #d8dde6; padding: 18px; }
          </style>
        </head>
        <body>
          <main>
            <header>
              <h1>Polymarket Inefficiency Scanner</h1>
              <div class="meta">read-only · #{escape(@config.bind_host)}:#{@config.port} · #{@opportunities.size} opportunities</div>
            </header>
            #{rows.empty? ? %(<div class="empty">No opportunities generated from the current real listings.</div>) : %(<table><thead><tr><th>ID</th><th>Detector</th><th>Status</th><th>Edge Net</th><th>Score</th><th>Risk Flags</th></tr></thead><tbody>#{rows}</tbody></table>)}
          </main>
        </body>
        </html>
        HTML
      end

      private def escape(value : String) : String
        value.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;")
      end
    end
  end
end
