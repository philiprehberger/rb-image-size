# frozen_string_literal: true

module Philiprehberger
  module ImageSize
    # Value object representing image dimensions and format
    #
    # @attr_reader width [Integer] image width in pixels
    # @attr_reader height [Integer] image height in pixels
    # @attr_reader format [Symbol] image format (:png, :jpeg, :gif, :bmp, :webp, :tiff, :ico, :cur, :svg, :avif)
    # @attr_reader animated [Boolean, nil] whether the image is animated
    # @attr_reader alpha [Boolean, nil] whether the image has an alpha channel
    # @attr_reader orientation [Integer, nil] EXIF orientation (1-8), nil if not applicable
    class ImageInfo
      attr_reader :width, :height, :format, :orientation

      # Create a new ImageInfo
      #
      # @param width [Integer] image width in pixels
      # @param height [Integer] image height in pixels
      # @param format [Symbol] image format
      # @param animated [Boolean, nil] whether the image is animated
      # @param alpha [Boolean, nil] whether the image has an alpha channel
      # @param orientation [Integer, nil] EXIF orientation (1-8)
      def initialize(width:, height:, format:, animated: nil, alpha: nil, orientation: nil)
        @width = width
        @height = height
        @format = format
        @animated = animated
        @alpha = alpha
        @orientation = orientation
      end

      # Whether the image is animated
      #
      # @return [Boolean]
      def animated?
        @animated == true
      end

      # Whether the image has an alpha channel
      #
      # @return [Boolean]
      def alpha?
        @alpha == true
      end

      # Return dimensions as an array
      #
      # @return [Array<Integer>] [width, height]
      def to_a
        [width, height]
      end

      # Return image info as a hash
      #
      # @return [Hash] { width:, height:, format:, animated:, alpha:, orientation: }
      def to_h
        {
          width: width,
          height: height,
          format: format,
          animated: animated?,
          alpha: alpha?,
          orientation: orientation
        }
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
