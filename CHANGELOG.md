# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-28

### Added

- TIFF format support with little-endian and big-endian byte order detection
- ICO/CUR format support with 256px dimension handling
- SVG dimension detection from width/height attributes and viewBox
- AVIF format support via ISOBMFF ftyp/ispe box parsing
- EXIF orientation detection for JPEG with automatic dimension swapping for rotated images
- Animation detection for GIF (NETSCAPE2.0), WebP (VP8X ANIM flag), and APNG (acTL chunk)
- Alpha channel detection for PNG (color type), WebP (VP8L alpha bit, VP8X alpha flag), and GIF (GCE transparency)
- `ImageInfo#animated?` method for animation detection
- `ImageInfo#alpha?` method for alpha channel detection
- `ImageInfo#orientation` attribute for EXIF orientation (1-8)

## [0.1.1] - 2026-03-26

### Added

- Add GitHub funding configuration

## [0.1.0] - 2026-03-26

### Added
- Initial release
- Detect image dimensions and format from file headers (PNG, JPEG, GIF, BMP, WebP)
- `ImageSize.of` returns `ImageInfo` with width, height, and format
- `ImageSize.dimensions` returns `[width, height]` array
- `ImageSize.format` returns format symbol
- Accepts file paths and IO objects (StringIO, File, etc.)
- Zero runtime dependencies
