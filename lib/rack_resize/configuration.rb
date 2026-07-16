require 'pathname'

class RackResize::Configuration
  PROCESSORS = %i[sips vips mini_magick imlib2].freeze

  attr_reader :processor
  attr_accessor :save_resized, :default_quality, :cache_folder, :assets_folder, :http_cache_max_age

  alias_method :save_resized?, :save_resized

  def initialize(options = {})
    @processor          = options[:processor] || RUBY_PLATFORM.include?('darwin') ? :sips : :mini_magick
    @save_resized       = options.key?(:save_resized) ? options[:save_resized] : false
    @default_quality    = options[:default_quality] || 95
    @cache_folder       = options[:cache_folder]
    @assets_folder      = options[:assets_folder] ? Pathname.new(options[:assets_folder]) : nil
    @http_cache_max_age = options[:http_cache_max_age] || 86400 # 1 day

    if defined?(Rails)
      @cache_folder ||= Rails.root.join('tmp', 'rack_resize_cache')
      @assets_folder ||= Rails.root.join('app', 'assets', 'images')
      unless options.key?(:save_resized)
        @save_resized = true
      end
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
                            when :mini_magick then RackResize::MiniMagick.new
                            when :vips        then RackResize::Processors::Vips.new
                            when :sips        then RackResize::Processors::Sips.new
                            when :imlib2      then RackResize::Processors::Imlib2.new
                            else
                              raise "RackResize - Unknow image processor #{@processor.inspect}"
                            end
  end
end
