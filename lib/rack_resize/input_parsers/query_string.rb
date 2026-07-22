module RackResize::InputParsers::QueryString
  extend self

  # Supports Fastly and bunny.net style query params:
  # /assets/photo.jpg?width=200&height=100&quality=85&fit=cover
  # /assets/photo.jpg?w=200&h=100&dpr=2&format=webp
  # /assets/photo.jpg?w=200&f=webp&q=80&fit=contain
  #
  # Shortcuts: f=format, q=quality

  CANONICAL_PARAMS = %w[width height quality dpr format fit bg-color background].freeze
  PARAM_ALIASES    = { 'f' => :format, 'q' => :quality, 'h' => :height, 'w' => :width, 'bg' => :'bg-color' }.freeze
  RESIZE_PARAMS    = (CANONICAL_PARAMS + PARAM_ALIASES.keys).freeze

  def parse_input(fullpath, query_string)
    params = Rack::Utils.parse_query(query_string.to_s)

    unless params.keys.any? { |k| RESIZE_PARAMS.include?(k) }
      return { route_matched: false, req_params: nil, asset_path: nil }
    end

    # Aliases are applied first; canonical names overwrite them if both are present.
    aliased   = params.slice(*PARAM_ALIASES.keys).transform_keys { |k| PARAM_ALIASES[k] }
    canonical = params.slice(*CANONICAL_PARAMS).transform_keys(&:to_sym)
    req_params = aliased.merge(canonical)
    asset_path = fullpath.sub(/-[\da-f]{8}(?=\.\w{2,}$)/, '')

    { route_matched: true, req_params:, asset_path: }
  end
end
