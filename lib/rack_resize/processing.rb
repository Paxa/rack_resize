require 'digest'
require 'fileutils'

class RackResize::Processing
  attr_reader :config

  def initialize(config:)
    @config = config
  end

  def process!(source_file:, req_params:)
    if config.save_resized?
      cache_key = Digest::MD5.hexdigest("#{source_file}:#{req_params.to_a.sort.to_s}")
      output_ext = output_extension(source_file, req_params[:format])
      tmp_file_name = config.cache_folder.join(cache_key + output_ext)
      FileUtils.mkdir_p(tmp_file_name.dirname)

      unless tmp_file_name.exist?
        process_file(req_params:, source_file:, target_file: tmp_file_name.to_s)
      end

      logger.info("Serving cached file #{tmp_file_name}")
      begin
        return StringIO.new(File.open(tmp_file_name.to_s, "rb", &:read))
      rescue Errno::ENOENT
        process_file(req_params:, source_file:, target_file: tmp_file_name.to_s)
        return StringIO.new(File.open(tmp_file_name.to_s, "rb", &:read))
      end
    else
      file_content = process_file(req_params:, source_file:, target_file: nil)
      return StringIO.new(file_content)
    end
  end

  def process_file(source_file:, req_params:, target_file: nil)
    dpr = req_params[:dpr]&.to_f || 1.0
    dpr = dpr.clamp(0.1, 10.0)

    max = config.max_dimension.to_f
    target_width  = (req_params[:w]&.to_i || req_params[:width]&.to_i)&.*(dpr)&.clamp(1, max)
    target_height = (req_params[:h]&.to_i || req_params[:height]&.to_i)&.*(dpr)&.clamp(1, max)

    fit     = req_params[:fit]
    format  = req_params[:format].then { |f| f == 'auto' ? nil : f }
    quality = req_params[:quality]&.to_i&.clamp(1, 100)

    start_time = Time.now
    begin
      return config.processor_instance.resize(source_file:, target_file:, target_width:, target_height:, fit:, format:, quality:)
    ensure
      processing_time = (Time.now.to_f - start_time.to_f).round(3)
      logger.info("RESIZE IMAGE #{config.processor} #{source_file} - #{req_params} - #{processing_time}s")
    end
  end

  def logger
    config.logger ||
      (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) ||
      (@_logger ||= (require 'logger'; Logger.new($stdout)))
  end

  private

  def output_extension(source_file, format)
    return File.extname(source_file) if format.nil?
    ".#{format.to_s.downcase}"
  end
end
