# philiprehberger-image_size

[![Tests](https://github.com/philiprehberger/rb-image-size/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-image-size/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-image_size.svg)](https://rubygems.org/gems/philiprehberger-image_size)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-image-size)](https://github.com/philiprehberger/rb-image-size/commits/main)

Image dimension detection from file headers without full decode

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

### Computed Properties

```ruby
info = Philiprehberger::ImageSize.of("photo.png")
info.aspect_ratio  # => 1.78
info.landscape?    # => true
info.portrait?     # => false
info.square?       # => false
info.area          # => 2073600
info.rotated?      # => false
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
| `#aspect_ratio` | Width divided by height as Float |
| `#landscape?` | Whether width > height |
| `#portrait?` | Whether height > width |
| `#square?` | Whether width == height |
| `#area` | Total pixel count (width * height) |
| `#rotated?` | Whether EXIF orientation indicates 90/270 rotation |
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

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-image-size)

🐛 [Report issues](https://github.com/philiprehberger/rb-image-size/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-image-size/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
