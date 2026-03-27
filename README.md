# philiprehberger-image_size

[![Tests](https://github.com/philiprehberger/rb-image-size/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-image-size/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-image_size.svg)](https://rubygems.org/gems/philiprehberger-image_size)
[![License](https://img.shields.io/github/license/philiprehberger/rb-image-size)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

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

```ruby
require "philiprehberger/image_size"

info = Philiprehberger::ImageSize.of("photo.png")
info.width   # => 1920
info.height  # => 1080
info.format  # => :png
```

### Dimensions Only

```ruby
require "philiprehberger/image_size"

width, height = Philiprehberger::ImageSize.dimensions("banner.jpg")
```

### Format Detection

```ruby
require "philiprehberger/image_size"

format = Philiprehberger::ImageSize.format("image.webp")
# => :webp
```

### IO Objects

```ruby
require "philiprehberger/image_size"

File.open("photo.gif", "rb") do |f|
  info = Philiprehberger::ImageSize.of(f)
  puts info.to_s  # => "GIF 320x240"
end
```

### ImageInfo Value Object

```ruby
require "philiprehberger/image_size"

info = Philiprehberger::ImageSize.of("photo.bmp")
info.to_a  # => [640, 480]
info.to_h  # => { width: 640, height: 480, format: :bmp }
```

## API

### `Philiprehberger::ImageSize`

| Method | Description |
|--------|-------------|
| `.of(path_or_io)` | Returns `ImageInfo` with width, height, and format |
| `.dimensions(path_or_io)` | Returns `[width, height]` array |
| `.format(path_or_io)` | Returns format symbol (`:png`, `:jpeg`, `:gif`, `:bmp`, `:webp`) |

### `Philiprehberger::ImageSize::ImageInfo`

| Method | Description |
|--------|-------------|
| `#width` | Image width in pixels |
| `#height` | Image height in pixels |
| `#format` | Format symbol |
| `#to_a` | Returns `[width, height]` |
| `#to_h` | Returns `{ width:, height:, format: }` |
| `#to_s` | Returns `"FORMAT WxH"` string |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

[MIT](LICENSE)
