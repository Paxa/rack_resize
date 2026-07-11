require 'pathname'

class LocalCdnCgi::Configuration
  PROCESSORS = %i[sips vips mini_magick].freeze

  attr_reader :processor
  attr_accessor :save_resized, :default_quality, :cache_folder, :assets_folder

  alias_method :save_resized?, :save_resized

  def initialize(options = {})
    @processor       = options[:processor] || RUBY_PLATFORM.include?('darwin') ? :sips : :mini_magick
    @save_resized    = options.key?(:save_resized) ? options[:save_resized] : true
    @default_quality = options[:default_quality] || 95
    @cache_folder    = options[:cache_folder]
    @assets_folder   = options[:assets_folder] ? Pathname.new(options[:assets_folder]) : nil

    if defined?(Rails)
      @cache_folder ||= Rails.root.join('tmp', 'cdn_cgi_cache')
      @assets_folder ||= Rails.root.join('app', 'assets', 'images')
    end

    if options[:processor]
      self.processor = options[:processor]
    end
  end

  def processor=(value)
    value = value.to_sym
    unless PROCESSORS.include?(value)
      raise ArgumentError, "Unknown processor #{value.inspect}. Must be one of: #{PROCESSORS.join(', ')}"
    end
    @processor = value
    @processor_instance = nil
  end

  def processor_instance
    @processor_instance ||= case @processor
                            when :mini_magick then LocalCdnCgi::MiniMagicProcessor.new
                            when :vips        then LocalCdnCgi::VipsProcessor.new
                            when :sips        then LocalCdnCgi::SipsProcessor.new
                            else
                              raise "LocalCdnCgi - Unknow image processor #{@processor.inspect}"
                            end
  end
end
