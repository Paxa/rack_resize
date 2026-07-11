require_relative "lib/local_cdn_cgi"
require "rack/static"

use LocalCdnCgi::RackApp, processor: :vips, save_resized: false, assets_folder: "samples"

use Rack::Static, urls: [""], root: "samples", index: "index.html"

run lambda { |env|
  [200, {'Content-Type' => 'text/html'}, ['Hello from Rack!']]
}
