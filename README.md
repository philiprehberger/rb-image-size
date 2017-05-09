# philiprehberger-image_size

[![Tests](https://github.com/philiprehberger/rb-image-size/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-image-size/actions/workflows/ci.yml) [![Gem Version](https://img.shields.io/gem/v/philiprehberger-image_size)](https://rubygems.org/gems/philiprehberger-image_size) [![GitHub release](https://img.shields.io/github/v/release/philiprehberger/rb-image-size)](https://github.com/philiprehberger/rb-image-size/releases) [![GitHub last commit](https://img.shields.io/github/last-commit/philiprehberger/rb-image-size)](https://github.com/philiprehberger/rb-image-size/commits/main) [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) [![Bug Reports](https://img.shields.io/badge/bug-reports-red.svg)](https://github.com/philiprehberger/rb-image-size/issues) [![Feature Requests](https://img.shields.io/badge/feature-requests-blue.svg)](https://github.com/philiprehberger/rb-image-size/issues) [![GitHub Sponsors](https://img.shields.io/badge/sponsor-philiprehberger-ea4aaa.svg?logo=github)](https://github.com/sponsors/philiprehberger)

Image dimension detection from file headers without full decode.

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-image_size"
```

Or install directly:

```bash
gem install philiprehberger-image_size
```

## Usage

### Basic Detection

```ruby
require "philiprehberger/image_size"

info = Philiprehberger::ImageSize.of("photo.png")
info.width   # => 1920
info.height  # => 1080
info.format  # => :png
```

### Dimensions Only

```ruby
width, height = Philiprehberger::ImageSize.dimensions("banner.jpg")
```

### Format Detection

```ruby
format = Philiprehberger::ImageSize.format("image.webp")
# => :webp
```

### IO Objects

```ruby
File.open("photo.gif", "rb") do |f|
  info = Philiprehberger::ImageSize.of(f)
  puts info.to_s  # => "GIF 320x240"
end
```

### Animation Detection

```ruby
info = Philiprehberger::ImageSize.of("animation.gif")
info.animated?  # => true
```

### Alpha Channel Detection

```ruby
info = Philiprehberger::ImageSize.of("transparent.png")
info.alpha?  # => true
```

### EXIF Orientation

```ruby
info = Philiprehberger::ImageSize.of("rotated.jpg")
info.orientation  # => 6
# Width and height reflect actual display dimensions (swapped for 90/270 rotation)
```

### ImageInfo Value Object

```ruby
info = Philiprehberger::ImageSize.of("photo.bmp")
info.to_a  # => [640, 480]
info.to_h  # => { width: 640, height: 480, format: :bmp, animated: false, alpha: false, orientation: nil }
```

## API

### `Philiprehberger::ImageSize`

| Method | Description |
|--------|-------------|
| `.of(path_or_io)` | Returns `ImageInfo` with width, height, format, and metadata |
| `.dimensions(path_or_io)` | Returns `[width, height]` array |
| `.format(path_or_io)` | Returns format symbol (`:png`, `:jpeg`, `:gif`, `:bmp`, `:webp`, `:tiff`, `:ico`, `:cur`, `:svg`, `:avif`) |

### `Philiprehberger::ImageSize::ImageInfo`

| Method | Description |
|--------|-------------|
| `#width` | Image width in pixels (display dimensions for rotated JPEG) |
| `#height` | Image height in pixels (display dimensions for rotated JPEG) |
| `#format` | Format symbol |
| `#animated?` | Whether the image is animated (GIF, WebP, APNG) |
| `#alpha?` | Whether the image has an alpha channel |
| `#orientation` | EXIF orientation (1-8), nil if not applicable |
| `#to_a` | Returns `[width, height]` |
| `#to_h` | Returns hash with all attributes |
| `#to_s` | Returns `"FORMAT WxH"` string |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Philip%20Rehberger-blue?logo=linkedin)](https://linkedin.com/in/philiprehberger) [![More Packages](https://img.shields.io/badge/more-packages-blue.svg)](https://github.com/philiprehberger?tab=repositories)

## License

[MIT](LICENSE)
