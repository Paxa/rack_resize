[![Gem Version](https://badge.fury.io/rb/rack_resize.svg)](https://badge.fury.io/rb/rack_resize)

How to use

```ruby
group :development do
  gem "rack_resize", require: "rack_resize/rails_autoload"
end
```

Supported processing backends:

| libaray           | dependency                                              | config                  |
|-------------------|---------------------------------------------------------|-------------------------|
| mini_magick       | ```ruby gem 'image_processing'<br>gem  'mini_magick'``` | processor: :mini_magick |
| vips              | ```ruby gem 'image_processing'<br>gem  'ruby-vips'```   | processor: :vips        |
| sips (MacOS only) | none                                                    | processor: :sips        |
| imlib2            | ```ruby gem  'rszr'```                                  | processor: :imlib2      |
