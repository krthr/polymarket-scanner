require "./app/application"

config_path = ENV["POLY_SCAN_CONFIG"]? || "config/app.example.yml"
serve = true

i = 0
while i < ARGV.size
  case ARGV[i]
  when "-c", "--config"
    i += 1
    config_path = ARGV[i]? || abort("missing value for --config")
  when "--once"
    serve = false
  when "--serve"
    serve = true
  when "-h", "--help"
    puts <<-HELP
    poly_scan [--config PATH] [--serve|--once]

      --config PATH  YAML config path. Defaults to POLY_SCAN_CONFIG or config/app.example.yml.
      --serve        Run fixture scan and start the local dashboard/API.
      --once         Run fixture scan, persist results, and print a summary.
    HELP
    exit 0
  else
    abort("unknown argument: #{ARGV[i]}")
  end
  i += 1
end

app = PolyScan::App::Application.boot(config_path)

if serve
  app.serve
else
  app.print_summary
end
