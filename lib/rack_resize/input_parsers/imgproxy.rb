module RackResize::InputParsers::Imgproxy
  extend self

  # Supports imgproxy URL formats:
  # /insecure/rs:fill:400:300/q:85/f:webp/plain/local:///assets/photo.jpg
  # /insecure/rs:fit:200:150/plain/local:///assets/banner.jpg@webp
  # /my-sig-123/w:400/h:300/q:80/plain/assets/photo.png
  # /insecure/plain/local:///assets/photo.jpg@avif

  REGEX = %r{\A/(?<signature>[^/]+)/(?:(?<options>(?:[a-z_]+:[^/]+/)*))plain/(?:local:///?|https?://[^/]+/)?(?<path>[^@\s]+?)(?:@(?<format>\w+))?\z}i

  def parse_input(fullpath)
    match = fullpath.to_s.match(REGEX)
    return { route_matched: false, req_params: nil, asset_path: nil } unless match

    req_params = {}

    if match[:options]
      match[:options].split("/").each do |part|
        next if part.empty?
        type, *args = part.split(":")
        case type.downcase
        when "rs", "resize"
          # rs:<type>:<width>:<height>:<enlarge>:<extend>
          req_params[:fit]    = map_fit(args[0]) if args[0] && !args[0].empty?
          req_params[:width]  = args[1] if args[1] && !args[1].empty? && args[1] != "0"
          req_params[:height] = args[2] if args[2] && !args[2].empty? && args[2] != "0"
        when "w", "width"
          req_params[:width] = args[0] if args[0] && !args[0].empty?
        when "h", "height"
          req_params[:height] = args[0] if args[0] && !args[0].empty?
        when "dpr"
          req_params[:dpr] = args[0] if args[0] && !args[0].empty?
        when "q", "quality"
          req_params[:quality] = args[0] if args[0] && !args[0].empty?
        when "f", "format", "ext"
          req_params[:format] = args[0] if args[0] && !args[0].empty?
        when "bg", "background"
          req_params[:background] = args.join(":") if args.any?
        when "fit"
          req_params[:fit] = map_fit(args[0]) if args[0] && !args[0].empty?
        end
      end
    end

    if match[:format]
      req_params[:format] = match[:format]
    end

    raw_path = match[:path]
    raw_path = "/" + raw_path unless raw_path.start_with?("/")
    asset_path = raw_path.sub(/-[\da-f]{8}(?=\.\w{2,}$)/, "")

    { route_matched: true, req_params: req_params, asset_path: asset_path }
  end

  private

  def map_fit(val)
    case val.to_s.downcase
    when "fill", "fill-down", "cover"
      "cover"
    when "fit", "contain"
      "contain"
    when "force"
      "fill"
    else
      val
    end
  end
end
