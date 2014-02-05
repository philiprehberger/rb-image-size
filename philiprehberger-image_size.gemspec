# frozen_string_literal: true

require_relative 'lib/philiprehberger/image_size/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-image_size'
  spec.version       = Philiprehberger::ImageSize::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']
  spec.summary       = 'Image dimension detection from file headers without full decode'
  spec.description   = 'Reads width, height, and format from image file headers (PNG, JPEG, GIF, BMP, WebP) ' \
                       'without loading the full image. Zero dependencies, fast, and memory-efficient.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-image-size'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
