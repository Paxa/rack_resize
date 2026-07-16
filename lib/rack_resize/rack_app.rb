# frozen_string_literal: true

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

    unless fullpath.start_with?(@cf_path_prefix)
      return @app.call(env)
    end

    # process string like this
    # /cdn-cgi/image/width=426,format=auto/assets/templates/vancouver-27c47f55.jpg

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

    return error_resp("invalid file path") unless asset_file.to_s.start_with?(config.assets_folder.to_s)
    return error_resp("file not exists on a server") unless asset_file.exist?

    file_content = @processing.process!(source_file: asset_file, req_params:)
    return send_file(asset_file:, file_content:)
  end

  def error_resp(message, http_code: 404)
    [http_code, {}, [message]]
  end

  def send_file(asset_file:, file_content: nil)
    content_type = Rack::Mime.mime_type(File.extname(asset_file), "application/octet-stream")

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
