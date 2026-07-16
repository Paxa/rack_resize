[![Gem Version](https://badge.fury.io/rb/rack_resize.svg)](https://badge.fury.io/rb/rack_resize)

Designed to be local simulation of CDN's resize feature

How to use with Rails

```ruby
group :development do
  gem "rack_resize", require: "rack_resize/rails_autoload"
end
```

How to use with Rack

```ruby
use RackResize::RackApp, processor: :imlib2, assets_folder: "samples"
use Rack::Static, urls: [""], root: "samples", index: "index.html" # optional
```

### URL Formats:

Cloudflare format: (can be used with helpers from `carrierwave-cloudflare` gem)
```
/cdn-cgi/image/width=426,format=auto/assets/pets/dog.jpg
```
Fastly and bunny.net: (tbd)
```
/assets/pets/dog.jpg?width=300
```

### Configuration:

```ruby
RackResize.configure do |config|
  config.assets_folder   = Rails.root.join('app', 'assets', 'images')
  config.processor       = :sips / :vips / :mini_magick / :imlib2
  config.default_quality = 95
  config.save_resized    = false
  config.cache_folder    = Rails.root.join('tmp', 'rack_resize_cache') # used if save_resized enabled
end
```

### Supported Processing Backends:

<table>
<tr>
<th>libaray</th>
<th>dependency</th>
<th>config</th>
</tr>
<tr>
<td>mini_magick</td>
<td>

```ruby
gem "image_processing"
gem  "mini_magick"
```

</td>
<td>

`processor: :mini_magick`

</td>
</tr>
<tr>
<td>vips</td>
<td>

```ruby
gem "image_processing"
gem  "ruby-vips"
```

</td>
<td>

`processor: :vips`

</td>
</tr>
<tr>
<td>sips (MacOS only)</td>
<td>none</td>
<td>

`processor: :sips`

</td>
</tr>
<tr>
<td>imlib2</td>
<td>

```ruby
gem  "rszr"
```

</td>
<td>

`processor: :imlib2`

</td>
</tr>
</table>
