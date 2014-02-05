# frozen_string_literal: true

require_relative 'image_size/version'
require_relative 'image_size/image_info'
require_relative 'image_size/detector'

module Philiprehberger
  module ImageSize
    class Error < StandardError; end

    # Detect image dimensions and format from a file path or IO object
    #
    # @param path_or_io [String, Pathname, IO, StringIO] file path or IO-like object
    # @return [ImageInfo] image info with width, height, and format
    # @raise [Error] if the file cannot be read or format is unrecognized
    def self.of(path_or_io)
      info = read_with(path_or_io) { |io| Detector.detect(io) }
      raise Error, 'Unrecognized image format' if info.nil?

      info
    end

    # Get image dimensions as [width, height]
    #
    # @param path_or_io [String, Pathname, IO, StringIO] file path or IO-like object
    # @return [Array<Integer>] [width, height]
    # @raise [Error] if the file cannot be read or format is unrecognized
    def self.dimensions(path_or_io)
      of(path_or_io).to_a
    end

    # Detect image format
    #
    # @param path_or_io [String, Pathname, IO, StringIO] file path or IO-like object
    # @return [Symbol] format symbol (:png, :jpeg, :gif, :bmp, :webp)
    # @raise [Error] if the file cannot be read or format is unrecognized
    def self.format(path_or_io)
      of(path_or_io).format
    end

    # @api private
    def self.read_with(path_or_io, &block)
      case path_or_io
      when String, Pathname
        File.open(path_or_io.to_s, 'rb', &block)
      else
        path_or_io.rewind if path_or_io.respond_to?(:rewind)
        block.call(path_or_io)
      end
    end

    private_class_method :read_with
  end
end
