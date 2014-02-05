# frozen_string_literal: true

module Philiprehberger
  module ImageSize
    # Value object representing image dimensions and format
    #
    # @attr_reader width [Integer] image width in pixels
    # @attr_reader height [Integer] image height in pixels
    # @attr_reader format [Symbol] image format (:png, :jpeg, :gif, :bmp, :webp)
    class ImageInfo
      attr_reader :width, :height, :format

      # Create a new ImageInfo
      #
      # @param width [Integer] image width in pixels
      # @param height [Integer] image height in pixels
      # @param format [Symbol] image format (:png, :jpeg, :gif, :bmp, :webp)
      def initialize(width:, height:, format:)
        @width = width
        @height = height
        @format = format
      end

      # Return dimensions as an array
      #
      # @return [Array<Integer>] [width, height]
      def to_a
        [width, height]
      end

      # Return image info as a hash
      #
      # @return [Hash] { width:, height:, format: }
      def to_h
        { width: width, height: height, format: format }
      end

      # Equality comparison
      #
      # @param other [ImageInfo] the other object
      # @return [Boolean]
      def ==(other)
        other.is_a?(self.class) &&
          width == other.width &&
          height == other.height &&
          format == other.format
      end

      # String representation
      #
      # @return [String]
      def to_s
        "#{format.upcase} #{width}x#{height}"
      end

      # Inspect representation
      #
      # @return [String]
      def inspect
        "#<#{self.class} format=#{format} width=#{width} height=#{height}>"
      end
    end
  end
end
