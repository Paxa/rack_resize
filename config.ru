require_relative "lib/rack_resize"
require "rack/static"

use RackResize::RackApp, processor: :imlib2, assets_folder: "samples" # save_resized: false,

use Rack::Static, urls: [""], root: "samples", index: "index.html"

run lambda { |env|
  [200, {'Content-Type' => 'text/html'}, ['Hello from Rack!']]
}
