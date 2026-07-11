# frozen_string_literal: true

require 'rack'

class LocalCdnCgi::RackApp

  attr_reader :config

  def initialize(*args, **options)
    pp [:args, args, options]

    if args.first
      @app = args.first
    end

    @config = options == {} ? LocalCdnCgi.config : LocalCdnCgi::Configuration.new(options)
    @path_prefix = options[:path_prefix] || "/cdn-cgi/image"
  end

  def call(env)
    # process string like this
    # /cdn-cgi/image/width=426,format=auto/assets/templates/vancouver-27c47f55.jpg

    request = Rack::Request.new(env)
    fullpath = request.path_info

    unless fullpath.start_with?(@path_prefix)
      return @app.call(env)
    end

    fullpath = fullpath.delete_prefix("/cdn-cgi").delete_prefix("/image").delete_prefix("/")
    file_path_match = fullpath.match(%r{(?<params>[^\/]+)(?<file>\/.+?)(-[\da-f]{8})?(?<ext>\.\w{2,})$})

    return error_resp("can't parse file path") unless file_path_match

    req_params = file_path_match[:params].split(",").map {|s| s.split("=") }.to_h.transform_keys(&:to_sym)
    asset_path = "#{file_path_match[:file]}#{file_path_match[:ext]}"

    if defined?(Rails)
      asset_path = asset_path.delete_prefix("/assets/")
    else
      asset_path = asset_path.delete_prefix("/#{config.assets_folder}/")
    end

    asset_file = config.assets_folder.join(asset_path.sub(%r{^/assets/}, ''))

    return error_resp(".. is not allowed in image path") if asset_path.include?("..")
    p [:asset_file, asset_file.to_s, config.assets_folder.to_s]

    return error_resp("invalid file path") unless asset_file.to_s.start_with?(config.assets_folder.to_s)
    return error_resp("file not exists on a server") unless asset_file.exist?

    if config.save_resized?
      tmp_file_name = config.cache_folder.join(Digest::MD5.hexdigest(fullpath) + file_path_match[:ext])
      FileUtils.mkdir_p(tmp_file_name.dirname)

      unless tmp_file_name.exist?
        process_file(req_params:, asset_file:, target_file: tmp_file_name.to_s)
      end

      logger.info("Serving cached file #{tmp_file_name}")
      return send_file(asset_file:, file_path: tmp_file_name.to_s)
    else
      file_content = process_file(req_params:, asset_file:, target_file: nil)
      return send_file(asset_file:, file_content:)
    end
  end

  def error_resp(message, http_code: 404)
    [http_code, {}, [message]]
  end

  def process_file(req_params:, target_file:, asset_file:)
    dpr = req_params[:dpr]&.to_f || 1.0
    target_width = (req_params[:w]&.to_i || req_params[:width]&.to_i)&.*(dpr)
    target_height = (req_params[:h]&.to_i || req_params[:height]&.to_i)&.*(dpr)

    start_time = Time.now
    begin
      return config.processor_instance.resize(source_file: asset_file, target_file:, target_width:, target_height:)

      # resize_with_ip_vips(source_file: asset_file, target_file:, target_width:, target_height:)
      # resize_with_ip_minimagic(source_file: asset_file, target_file:, target_width:, target_height:)
      # resize_with_minimagic(source_file: asset_file, target_file:, target_width:, target_height:)
    ensure
      processing_time = (Time.now.to_f - start_time.to_f).round(3)
      logger.info("RESIZE IMAGE #{config.processor} #{asset_file} - #{req_params} - #{processing_time}s")
    end
  end

  def logger
    @logger ||= begin
      if defined?(Rails) && Rails.logger
        Rails.logger
      else
        require 'logger'
        Logger.new(STDOUT)
        end
    end
  end

  def send_file(asset_file:, file_path: nil, file_content: nil)
    content_type = Rack::Mime.mime_type(File.extname(asset_file), "application/octet-stream")
    file = file_path ? File.open(file_path, "rb") : StringIO.new(file_content)

    [
      200,
      {
        "content-type"        => content_type,
        "content-length"      => file.size.to_s,
        "content-disposition" => "inline",
        "cache-control"       => "max-age=86400" # 1 day
      },
      file
    ]
  end
end
