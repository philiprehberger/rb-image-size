# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-26

### Added
- Initial release
- Detect image dimensions and format from file headers (PNG, JPEG, GIF, BMP, WebP)
- `ImageSize.of` returns `ImageInfo` with width, height, and format
- `ImageSize.dimensions` returns `[width, height]` array
- `ImageSize.format` returns format symbol
- Accepts file paths and IO objects (StringIO, File, etc.)
- Zero runtime dependencies
