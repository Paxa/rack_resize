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
Fastly / bunny.net format (query string params):
```
/assets/pets/dog.jpg?width=300&height=200&fit=cover&format=webp&quality=85
```
Shortcuts: `w`/`h` for width/height, `f` for format, `q` for quality.

### Configuration:

```ruby
RackResize.configure do |config|
  config.assets_folders     = { "assets" => Rails.root.join('app', 'assets', 'images') }
  config.processor          = :sips / :vips / :mini_magick / :imlib2
  config.default_quality    = 95
  config.save_resized       = false
  config.cache_folder       = Rails.root.join('tmp', 'rack_resize_cache') # used if save_resized enabled
  config.http_cache_max_age = 86400
end
```

### Supported Processing Backends:

<table>
<tr>
<th>processor</th>
<th>config</th>
<th>system library</th>
<th>gems</th>
</tr>
<tr>
<td>sips (macOS only)</td>
<td><code>processor: :sips</code></td>
<td>built-in on macOS</td>
<td>none</td>
</tr>
<tr>
<td>mini_magick</td>
<td><code>processor: :mini_magick</code></td>
<td>

ImageMagick — `brew install imagemagick`

</td>
<td>

```ruby
gem "image_processing"
gem "mini_magick"
```

</td>
</tr>
<tr>
<td>vips</td>
<td><code>processor: :vips</code></td>
<td>

libvips — `brew install vips`

</td>
<td>

```ruby
gem "image_processing"
gem "ruby-vips"
```

</td>
</tr>
<tr>
<td>imlib2</td>
<td><code>processor: :imlib2</code></td>
<td>

Imlib2 — `brew install imlib2`

</td>
<td>

```ruby
gem "rszr"
```

</td>
</tr>
</table>

### Supported Image Formats:

| Format | sips | mini_magick | vips | imlib2 |
|--------|:----:|:-----------:|:----:|:------:|
| JPEG   | ✅   | ✅          | ✅   | ✅     |
| PNG    | ✅   | ✅          | ✅   | ✅     |
| GIF    | ✅   | ✅          | ✅   | ✅     |
| WebP   | ❌   | ✅ ¹        | ✅ ¹ | ❌     |
| AVIF   | ✅ ² | ✅ ³        | ✅ ⁴ | ❌     |
| HEIC   | ✅   | ✅ ³        | ✅ ⁴ | ❌     |
| SVG    | ❌   | ✅ ⁵        | ✅ ⁶ | ❌     |

¹ Requires ImageMagick / libvips built with **libwebp** support (`brew install webp`)
² macOS 13 (Ventura) or later
³ Requires ImageMagick built with **libheif** support (`brew install libheif`)
⁴ Requires libvips built with **libheif** support (`brew install libheif`)
⁵ Requires **Inkscape** or **librsvg** (`brew install librsvg`)
⁶ Requires libvips built with **librsvg** support (`brew install librsvg`)

### Performance Benchmarks:

Measured on an Apple M1 Pro with Ruby 4.0.5. Output size: 300×200 px.
Run with `ruby benchmark/processor_benchmark.rb`

**JPEG — image_1.jpeg (51 KB)**

| Processor   | i/s   | ms/i  | vs fastest |
|-------------|------:|------:|:----------:|
| imlib2      | 613.0 | 1.63  | —          |
| vips        | 216.9 | 4.61  | 2.83×      |
| mini_magick |  36.4 | 27.49 | 16.85×     |
| sips        |  20.1 | 49.68 | 30.45×     |

**PNG — sample.png (2 KB)**

| Processor   | i/s   | ms/i | vs fastest |
|-------------|------:|-----:|:----------:|
| vips        | 431.1 | 2.32 | —          |
| imlib2      | 221.7 | 4.51 | 1.94×      |
| mini_magick |  36.9 | 27.12| 11.69×     |
| sips        |  19.4 | 51.62| 22.25×     |
