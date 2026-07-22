module RackResize
  autoload :Configuration, "#{__dir__}/rack_resize/configuration"
  autoload :RackApp,       "#{__dir__}/rack_resize/rack_app"
  autoload :Processing,    "#{__dir__}/rack_resize/processing"
  autoload :ColorUtils,    "#{__dir__}/rack_resize/color_utils"

  module Processors
    autoload :Sips,       "#{__dir__}/rack_resize/processors/sips"
    autoload :Vips,       "#{__dir__}/rack_resize/processors/vips"
    autoload :MiniMagick, "#{__dir__}/rack_resize/processors/mini_magick"
    autoload :Imlib2,     "#{__dir__}/rack_resize/processors/imlib2"
  end

  module InputParsers
    autoload :Cloudflare,  "#{__dir__}/rack_resize/input_parsers/cloudflare"
    autoload :QueryString, "#{__dir__}/rack_resize/input_parsers/query_string"
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def config
      configuration
    end

    def configure
      yield configuration
    end
  end
end
