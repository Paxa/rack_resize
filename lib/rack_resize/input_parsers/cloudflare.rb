module RackResize::InputParsers::Cloudflare
  extend self

  # process string like this
  # /cdn-cgi/image/width=426,format=auto/assets/templates/vancouver-27c47f55.jpg

  def parse_input(fullpath, cf_path_prefix:)
    unless fullpath.start_with?(cf_path_prefix)
      return { route_matched: false, req_params: nil, asset_path: nil }
    end

    fullpath = fullpath.delete_prefix("/cdn-cgi").delete_prefix("/image").delete_prefix("/")
    file_path_match = fullpath.match(%r{(?<params>[^\/]+)(?<file>\/.+?)(-[\da-f]{8})?(?<ext>\.\w{2,})$})

    return { route_matched: true, req_params: nil, asset_path: nil } unless file_path_match

    req_params = file_path_match[:params].split(",").map {|s| s.split("=") }.to_h.transform_keys(&:to_sym)
    asset_path = "#{file_path_match[:file]}#{file_path_match[:ext]}"

    { route_matched: true, req_params:, asset_path: }
  end
end
