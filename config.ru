#
# usage:
#   gem install rackup
#   rackup
#

require_relative "lib/rack_resize"
require "rack/static"

use RackResize::RackApp, processor: :vips, assets_folders: ["samples"]

use Rack::Static, urls: [""], root: "samples", index: "index.html"

run lambda { |env|
  [200, {'Content-Type' => 'text/html'}, ['Hello from Rack!']]
}
