require 'rack'

class RackResize::RackApp

  attr_reader :config

  def initialize(*args, **options)
    if args.first
      @app = args.first
    end

    @config = options == {} ? RackResize.config : RackResize::Configuration.new(options)
    @processing = RackResize::Processing.new(config: @config)
    @cf_path_prefix = options[:cf_path_prefix] || "/cdn-cgi/image"
  end

  def call(env)
    request = Rack::Request.new(env)
    fullpath = request.path_info

    result = RackResize::InputParsers::Cloudflare.parse_input(fullpath, cf_path_prefix: @cf_path_prefix)
    result = RackResize::InputParsers::QueryString.parse_input(fullpath, request.query_string) unless result[:route_matched]
    result => {route_matched:, req_params:, asset_path:}

    return @app.call(env) unless route_matched
    return error_resp("can't parse file path") unless asset_path

    return error_resp("no assets folders configured") if config.assets_folders.nil? || config.assets_folders.empty?

    has_matched = false
    asset_file = nil
    config.assets_folders.each do |prefix, folder|
      if asset_path.start_with?(prefix)
        asset_file = folder.join(asset_path.delete_prefix(prefix + (prefix.end_with?("/") ? "" : "/")))
        if asset_file.expand_path.to_s.start_with?(folder.to_s)
          has_matched = true
        end
        break
      end
    end

    if asset_path.include?("..")
      @processing.logger.info("RackResize::RackApp - File path has invalid byte sequence #{asset_path}")
      return error_resp(".. is not allowed in image path")
    end
    unless has_matched
      @processing.logger.info("RackResize::RackApp - requested file #{asset_path} not match any of configured assets folder #{config.assets_folders.keys}")
      return error_resp("invalid file path")
    end
    unless asset_file.exist?
      @processing.logger.info("RackResize::RackApp - File path not found #{asset_path} => #{asset_file}")
      return error_resp("file not exists on a server")
    end

    file_content = @processing.process!(source_file: asset_file, req_params:)
    output_format = req_params[:format].then { |f| (f && f != 'auto') ? f : nil }
    return send_file(asset_file:, file_content:, output_format:)
  end

  def error_resp(message, http_code: 404)
    [http_code, {}, [message]]
  end

  def send_file(asset_file:, file_content: nil, output_format: nil)
    ext = (output_format && output_format != 'auto') ? ".#{output_format}" : File.extname(asset_file)
    content_type = Rack::Mime.mime_type(ext, "application/octet-stream")

    [
      200,
      {
        "content-type"        => content_type,
        "content-length"      => file_content.size.to_s,
        "content-disposition" => "inline",
        "cache-control"       => "max-age=#{config.http_cache_max_age}" # 1 day
      },
      file_content
    ]
  end
end
