# frozen_string_literal: true
#
# HTTP benchmark: starts a WEBrick server in a background thread, mounts one
# RackResize::RackApp per available processor at a distinct path prefix, then
# measures throughput with benchmark-ips over persistent HTTP connections.
#
# Usage:
#   bundle exec ruby benchmark/http_benchmark.rb

require 'bundler/setup'
require 'rack'
require 'webrick'
require 'net/http'
require 'benchmark/ips'
require 'logger'
require 'stringio'
require 'timeout'
require_relative '../lib/rack_resize'

SAMPLES_DIR  = File.expand_path('../samples', __dir__)
BENCH_PORT   = 14_569
BENCH_IMAGE  = 'image_1.jpeg'
BENCH_PARAMS = 'width=300&height=200'
NULL_LOGGER  = Logger.new(IO::NULL)

# ── One RackApp per available processor ──────────────────────────────────────

available_apps = {}

puts "Loading processors..."
%i[sips vips mini_magick imlib2].each do |name|
  begin
    app = RackResize::RackApp.new(
      processor:      name,
      assets_folders: { '/' => SAMPLES_DIR },
      save_resized:   false,
      logger:         NULL_LOGGER,
    )
    available_apps[name] = app
    puts "  ✓ #{name}"
  rescue => e
    puts "  ✗ #{name}: #{e.message}"
  end
end

abort "\nNo processors available." if available_apps.empty?

# ── URLMap: /sips → sips_app, /vips → vips_app, etc. ────────────────────────

rack_app = Rack::Builder.new do
  available_apps.each do |name, app|
    map("/#{name}") { run app }
  end
end.to_app

# ── WEBrick with a minimal Rack env bridge ───────────────────────────────────

webrick = WEBrick::HTTPServer.new(
  Port:      BENCH_PORT,
  Logger:    WEBrick::Log.new(IO::NULL),
  AccessLog: [],
)

webrick.mount_proc('/') do |req, res|
  env = {
    'REQUEST_METHOD'    => req.request_method,
    'PATH_INFO'         => req.path,
    'QUERY_STRING'      => req.query_string.to_s,
    'SERVER_NAME'       => 'localhost',
    'SERVER_PORT'       => BENCH_PORT.to_s,
    'HTTP_HOST'         => "localhost:#{BENCH_PORT}",
    'SCRIPT_NAME'       => '',
    'rack.version'      => Rack::VERSION,
    'rack.input'        => StringIO.new(''),
    'rack.errors'       => $stderr,
    'rack.multithread'  => true,
    'rack.multiprocess' => false,
    'rack.run_once'     => false,
    'rack.url_scheme'   => 'http',
  }
  req.header.each do |key, values|
    env["HTTP_#{key.upcase.tr('-', '_')}"] = values.join(', ')
  end

  status, headers, body = rack_app.call(env)

  res.status = status
  headers.each { |k, v| res[k] = v }
  body_str = +''
  body.each { |chunk| body_str << chunk }
  res.body = body_str
end

server_thread = Thread.new { webrick.start }

Timeout.timeout(10) do
  loop do
    TCPSocket.new('localhost', BENCH_PORT).close
    break
  rescue Errno::ECONNREFUSED
    sleep 0.05
  end
end

puts "\nServer listening on port #{BENCH_PORT}"

# ── Smoke-test each endpoint before benchmarking ─────────────────────────────

puts "\nVerifying endpoints..."
available_apps.keys.each do |name|
  uri  = URI("http://localhost:#{BENCH_PORT}/#{name}/#{BENCH_IMAGE}?#{BENCH_PARAMS}")
  resp = Net::HTTP.get_response(uri)
  if resp.is_a?(Net::HTTPOK)
    puts "  ✓ /#{name}/#{BENCH_IMAGE} → 200 (#{resp.body.bytesize} B)"
  else
    warn "  ✗ /#{name}/#{BENCH_IMAGE} → #{resp.code}: #{resp.body}"
    available_apps.delete(name)
  end
end

abort "\nNo processors passed smoke test." if available_apps.empty?

# ── Persistent HTTP connections, one per processor ───────────────────────────

connections = available_apps.keys.to_h do |name|
  http = Net::HTTP.new('localhost', BENCH_PORT)
  http.start
  [name, http]
end

puts "\n── HTTP rack server benchmark ───────────────────────────────────────────────"
puts "   image : #{BENCH_IMAGE}"
puts "   params: #{BENCH_PARAMS}"
puts

Benchmark.ips do |x|
  x.config(time: 10, warmup: 3)

  connections.each do |name, http|
    path = "/#{name}/#{BENCH_IMAGE}?#{BENCH_PARAMS}"
    x.report(name.to_s) { http.get(path) }
  end

  x.compare!
end

# ── Cleanup ───────────────────────────────────────────────────────────────────

connections.each_value(&:finish)
webrick.shutdown
server_thread.join
