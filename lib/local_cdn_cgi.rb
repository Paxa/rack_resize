module LocalCdnCgi
  autoload :Configuration,      "#{__dir__}/local_cdn_cgi/configuration"
  autoload :RackApp,            "#{__dir__}/local_cdn_cgi/rack_app"
  autoload :SipsProcessor,      "#{__dir__}/local_cdn_cgi/sips_processor"
  autoload :VipsProcessor,      "#{__dir__}/local_cdn_cgi/vips_processor"
  autoload :MiniMagicProcessor, "#{__dir__}/local_cdn_cgi/mini_magic_processor"
  autoload :ImageController,    "#{__dir__}/local_cdn_cgi/image_controller"

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
