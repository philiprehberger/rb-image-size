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
    # @attr_reader dpi [Hash, nil] DPI as { x: Float, y: Float }, nil if not available
    # @attr_reader color_depth [Integer, nil] bits per pixel, nil if not detectable
    # @attr_reader interlaced [Boolean, nil] whether the image uses interlaced/progressive encoding
    class ImageInfo
      attr_reader :width, :height, :format, :orientation, :dpi, :color_depth

      # Create a new ImageInfo
      #
      # @param width [Integer] image width in pixels
      # @param height [Integer] image height in pixels
      # @param format [Symbol] image format
      # @param animated [Boolean, nil] whether the image is animated
      # @param alpha [Boolean, nil] whether the image has an alpha channel
      # @param orientation [Integer, nil] EXIF orientation (1-8)
      # @param dpi [Hash, nil] DPI as { x: Float, y: Float }
      # @param color_depth [Integer, nil] bits per pixel
      # @param interlaced [Boolean, nil] whether the image uses interlaced/progressive encoding
      def initialize(width:, height:, format:, animated: nil, alpha: nil, orientation: nil, dpi: nil, color_depth: nil,
                     interlaced: nil)
        @width = width
        @height = height
        @format = format
        @animated = animated
        @alpha = alpha
        @orientation = orientation
        @dpi = dpi
        @color_depth = color_depth
        @interlaced = interlaced
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

      # Whether the image uses interlaced/progressive encoding
      #
      # @return [Boolean]
      def interlaced?
        @interlaced == true
      end

      # Calculate aspect ratio (width / height)
      #
      # @return [Float]
      def aspect_ratio
        return 0.0 if height.zero?

        width.to_f / height
      end

      # Whether the image is wider than tall
      #
      # @return [Boolean]
      def landscape?
        width > height
      end

      # Whether the image is taller than wide
      #
      # @return [Boolean]
      def portrait?
        height > width
      end

      # Whether the image has equal width and height
      #
      # @return [Boolean]
      def square?
        width == height
      end

      # Total pixel area
      #
      # @return [Integer]
      def area
        width * height
      end

      # Megapixels (area / 1,000,000), rounded to 1 decimal place
      #
      # @return [Float]
      def megapixels
        (area / 1_000_000.0).round(1)
      end

      # Dimensions scaled to fit inside a bounding box while preserving aspect
      # ratio. Never upscales — returns the original dimensions when the image
      # is already smaller than the box.
      #
      # @param max_width [Integer] maximum width of the bounding box in pixels
      # @param max_height [Integer] maximum height of the bounding box in pixels
      # @return [Array<Integer>] [width, height] scaled to fit
      def fit_within(max_width, max_height)
        return [width, height] if width <= max_width && height <= max_height

        scale = [max_width.to_f / width, max_height.to_f / height].min
        [(width * scale).round, (height * scale).round]
      end

      # Whether EXIF orientation indicates 90/270 degree rotation
      #
      # @return [Boolean]
      def rotated?
        orientation ? orientation.between?(5, 8) : false
      end

      # Return dimensions as an array
      #
      # @return [Array<Integer>] [width, height]
      def to_a
        [width, height]
      end

      # Return image info as a hash
      #
      # @return [Hash] { width:, height:, format:, animated:, alpha:, orientation:, dpi:, color_depth:, megapixels: }
      def to_h
        {
          width: width,
          height: height,
          format: format,
          animated: animated?,
          alpha: alpha?,
          interlaced: interlaced?,
          orientation: orientation,
          dpi: dpi,
          color_depth: color_depth,
          megapixels: megapixels
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
