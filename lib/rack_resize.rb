module RackResize
  autoload :Configuration, "#{__dir__}/rack_resize/configuration"
  autoload :RackApp,       "#{__dir__}/rack_resize/rack_app"
  autoload :Processing,    "#{__dir__}/rack_resize/processing"
  # autoload :ImageController,    "#{__dir__}/rack_resize/image_controller"

  module Processors
    autoload :Sips,      "#{__dir__}/rack_resize/processors/sips"
    autoload :Vips,      "#{__dir__}/rack_resize/processors/vips"
    autoload :MiniMagic, "#{__dir__}/rack_resize/processors/mini_magic"
    autoload :Imlib2,    "#{__dir__}/rack_resize/processors/imlib2"
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
