require 'digest'

class RackResize::Processing
  attr_reader :config

  def initialize(config:)
    @config = config
  end

  def process!(source_file:, req_params:)
    if config.save_resized?
      tmp_file_name = config.cache_folder.join(Digest::MD5.hexdigest(source_file.to_s) + File.extname(source_file))
      FileUtils.mkdir_p(tmp_file_name.dirname)

      unless tmp_file_name.exist?
        process_file(req_params:, source_file:, target_file: tmp_file_name.to_s)
      end

      logger.info("Serving cached file #{tmp_file_name}")
      return StringIO.new(File.open(tmp_file_name.to_s, "rb", &:read))
    else
      file_content = process_file(req_params:, source_file:, target_file: nil)
      return StringIO.new(file_content)
    end
  end

  def process_file(source_file:, req_params:, target_file: nil)
    dpr = req_params[:dpr]&.to_f || 1.0
    dpr = [[dpr, 0.1].max, 10.0].min

    max = config.max_dimension.to_f
    target_width  = (req_params[:w]&.to_i || req_params[:width]&.to_i)&.*(dpr)&.clamp(1, max)
    target_height = (req_params[:h]&.to_i || req_params[:height]&.to_i)&.*(dpr)&.clamp(1, max)

    start_time = Time.now
    begin
      return config.processor_instance.resize(source_file:, target_file:, target_width:, target_height:)
    ensure
      processing_time = (Time.now.to_f - start_time.to_f).round(3)
      logger.info("RESIZE IMAGE #{config.processor} #{source_file} - #{req_params} - #{processing_time}s")
    end
  end

  def logger
    config.logger ||
      (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) ||
      (require('logger') && Logger.new(STDOUT))
  end
end
