require 'pathname'

class RackResize::Configuration
  PROCESSORS = %i[sips vips mini_magick imlib2].freeze

  attr_reader :processor, :assets_folders
  attr_accessor :save_resized, :default_quality, :cache_folder, :http_cache_max_age

  alias_method :save_resized?, :save_resized

  def initialize(options = {})
    @processor          = options[:processor] || RUBY_PLATFORM.include?('darwin') ? :sips : :mini_magick
    @save_resized       = options.key?(:save_resized) ? options[:save_resized] : false
    @default_quality    = options[:default_quality] || 95
    @cache_folder       = options[:cache_folder]
    @http_cache_max_age = options[:http_cache_max_age] || 86400 # 1 day

    self.assets_folders = options[:assets_folders] if options[:assets_folders]

    if defined?(Rails)
      @cache_folder ||= Rails.root.join('tmp', 'rack_resize_cache')
      self.assets_folders = {
        "assets"  => Rails.root.join("app/assets/images"),
        "uploads" => Rails.root.join("public/uploads"),
      }
      unless options.key?(:save_resized)
        @save_resized = true
      end
    end

    if options[:processor]
      self.processor = options[:processor]
    end
  end

  def assets_folders=(values)
    if values.is_a?(Array)
      @assets_folders = values.map { |v| [format_asset_path(v), Pathname.new(v)] }.to_h
    elsif values.is_a?(Hash)
      @assets_folders = values.transform_values { |v| v.is_a?(Pathname) ? v : Pathname.new(v) }
                              .transform_keys {|k| format_asset_path(k) }
    else
      raise ArgumentError, "RackResize::Configuration.assets_folders can be either hash or array, received #{values.class}"
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
                            when :mini_magick then RackResize::Processors::MiniMagick.new
                            when :vips        then RackResize::Processors::Vips.new
                            when :sips        then RackResize::Processors::Sips.new
                            when :imlib2      then RackResize::Processors::Imlib2.new
                            else
                              raise "RackResize - Unknow image processor #{@processor.inspect}"
                            end
  end

  private

  def format_asset_path(path)
    path.start_with?('/') ? path.to_s : "/#{path}"
  end
end
