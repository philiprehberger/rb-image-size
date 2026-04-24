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

### Megapixels

```ruby
info = Philiprehberger::ImageSize.of("photo.png")
info.megapixels  # => 2.1
```

### DPI Extraction

```ruby
info = Philiprehberger::ImageSize.of("print-ready.jpg")
info.dpi  # => { x: 300.0, y: 300.0 } or nil if not available
```

Supported sources: JPEG (JFIF APP0), PNG (pHYs chunk), TIFF (resolution tags), BMP (pixels per meter).

### Color Depth

```ruby
info = Philiprehberger::ImageSize.of("photo.png")
info.color_depth  # => 24 (bits per pixel) or nil if not detectable
```

Supported formats: PNG (bit depth * channels), BMP (from header), JPEG (precision * components from SOF marker).

### Interlace Detection

```ruby
info = Philiprehberger::ImageSize.of("progressive.jpg")
info.interlaced?  # => true (progressive JPEG)

info = Philiprehberger::ImageSize.of("interlaced.png")
info.interlaced?  # => true (Adam7 interlacing)
```

### Computed Properties

```ruby
info = Philiprehberger::ImageSize.of("photo.png")
info.aspect_ratio  # => 1.78
info.landscape?    # => true
info.portrait?     # => false
info.square?       # => false
info.area          # => 2073600
info.megapixels    # => 2.1
info.rotated?      # => false
```

### Fit Within a Bounding Box

```ruby
info = Philiprehberger::ImageSize.of("photo.png") # 1920x1080
info.fit_within(400, 400)  # => [400, 225]   # scaled down, aspect preserved
info.fit_within(3000, 3000) # => [1920, 1080] # no upscale
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
| `#interlaced?` | Whether the image uses interlaced (PNG Adam7) or progressive (JPEG) encoding |
| `#orientation` | EXIF orientation (1-8), nil if not applicable |
| `#aspect_ratio` | Width divided by height as Float |
| `#landscape?` | Whether width > height |
| `#portrait?` | Whether height > width |
| `#square?` | Whether width == height |
| `#area` | Total pixel count (width * height) |
| `#megapixels` | Area in megapixels, rounded to 1 decimal |
| `#dpi` | DPI as `{ x: Float, y: Float }` hash, or nil |
| `#color_depth` | Bits per pixel (PNG, BMP, JPEG), or nil |
| `#rotated?` | Whether EXIF orientation indicates 90/270 rotation |
| `#fit_within(max_w, max_h)` | Returns `[w, h]` scaled to fit inside a bounding box (preserves aspect ratio, never upscales) |
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
