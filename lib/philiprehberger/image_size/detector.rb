# frozen_string_literal: true

module Philiprehberger
  module ImageSize
    # Core detection logic that reads minimal bytes from image file headers
    # to determine format and dimensions without decoding the full image.
    module Detector
      SOF_MARKERS = [0xFFC0, 0xFFC2].freeze
      PNG_SIGNATURE = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack('C8').freeze
      JPEG_SIGNATURE = [0xFF, 0xD8].pack('C2').freeze

      class << self
        # Detect image format and dimensions from an IO-like object
        #
        # @param io [IO, StringIO] an IO object positioned at the start
        # @return [ImageInfo, nil] image info or nil if format is unrecognized
        def detect(io)
          header = io.read(32)
          return nil if header.nil? || header.length < 8

          detect_png(header) ||
            detect_jpeg(io, header) ||
            detect_gif(header) ||
            detect_bmp(header) ||
            detect_webp(io, header)
        end

        private

        # PNG: 8-byte signature followed by IHDR chunk containing width and height
        def detect_png(header)
          return nil unless header.start_with?(PNG_SIGNATURE)
          return nil if header.length < 24

          width = header[16, 4].unpack1('N')
          height = header[20, 4].unpack1('N')

          ImageInfo.new(width: width, height: height, format: :png)
        end

        # JPEG: Starts with FF D8, dimensions in SOF0 (FF C0) or SOF2 (FF C2) marker
        def detect_jpeg(io, header)
          return nil unless header[0, 2] == JPEG_SIGNATURE

          io.seek(2)
          find_jpeg_sof(io)
        end

        # Scan JPEG markers until SOF0/SOF2 is found, then extract dimensions
        def find_jpeg_sof(io)
          loop do
            marker = read_jpeg_marker(io)
            return nil if marker.nil?

            return parse_sof_dimensions(io) if SOF_MARKERS.include?(marker)

            skip_jpeg_segment(io) || return
          end
        end

        # Read a 2-byte JPEG marker from the IO
        def read_jpeg_marker(io)
          bytes = io.read(2)
          return nil if bytes.nil? || bytes.length < 2

          bytes.unpack1('n')
        end

        # Parse width and height from SOF segment (after marker)
        def parse_sof_dimensions(io)
          data = io.read(7)
          return nil if data.nil? || data.length < 7

          # 2-byte length + 1-byte precision + 2-byte height + 2-byte width
          height = data[3, 2].unpack1('n')
          width = data[5, 2].unpack1('n')

          ImageInfo.new(width: width, height: height, format: :jpeg)
        end

        # Skip a JPEG segment by reading its length and seeking past it
        def skip_jpeg_segment(io)
          length_bytes = io.read(2)
          return nil if length_bytes.nil? || length_bytes.length < 2

          length = length_bytes.unpack1('n')
          return nil if length < 2

          io.seek(length - 2, IO::SEEK_CUR)
          true
        end

        # GIF: Starts with "GIF87a" or "GIF89a", width and height at bytes 6-9 (little-endian)
        def detect_gif(header)
          return nil unless header.start_with?('GIF87a') || header.start_with?('GIF89a')
          return nil if header.length < 10

          width = header[6, 2].unpack1('v')
          height = header[8, 2].unpack1('v')

          ImageInfo.new(width: width, height: height, format: :gif)
        end

        # BMP: Starts with "BM", width at bytes 18-21 and height at bytes 22-25 (little-endian, signed)
        def detect_bmp(header)
          return nil unless header.start_with?('BM')
          return nil if header.length < 26

          width = header[18, 4].unpack1('V')
          height = header[22, 4].unpack1('l<').abs

          ImageInfo.new(width: width, height: height, format: :bmp)
        end

        # WebP: Starts with "RIFF" + 4 bytes size + "WEBP"
        def detect_webp(io, header)
          return nil unless webp_header?(header)

          detect_webp_chunk(io, header[12, 4], header)
        end

        def webp_header?(header)
          header[0, 4] == 'RIFF' && header[8, 4] == 'WEBP' && header.length >= 30
        end

        def detect_webp_chunk(io, chunk_type, header)
          case chunk_type
          when 'VP8 ' then detect_webp_vp8(header)
          when 'VP8L' then detect_webp_vp8l(header)
          when 'VP8X' then detect_webp_vp8x(io)
          end
        end

        # VP8 (lossy): dimensions at bytes 26-29 (little-endian, masked to 14 bits)
        def detect_webp_vp8(header)
          return nil if header.length < 30

          width = header[26, 2].unpack1('v') & 0x3FFF
          height = header[28, 2].unpack1('v') & 0x3FFF

          ImageInfo.new(width: width, height: height, format: :webp)
        end

        # VP8L (lossless): dimensions packed into 4 bytes at offset 21
        def detect_webp_vp8l(header)
          return nil if header.length < 25

          bits = header[21, 4].unpack1('V')
          width = (bits & 0x3FFF) + 1
          height = ((bits >> 14) & 0x3FFF) + 1

          ImageInfo.new(width: width, height: height, format: :webp)
        end

        # VP8X (extended): canvas dimensions at bytes 24-29 (24-bit LE + 1)
        def detect_webp_vp8x(io)
          io.seek(24)
          data = io.read(6)
          return nil if data.nil? || data.length < 6

          width = unpack_24bit_le(data, 0) + 1
          height = unpack_24bit_le(data, 3) + 1

          ImageInfo.new(width: width, height: height, format: :webp)
        end

        # Unpack a 24-bit little-endian integer from data at given offset
        def unpack_24bit_le(data, offset)
          data[offset].ord | (data[offset + 1].ord << 8) | (data[offset + 2].ord << 16)
        end
      end
    end
  end
end
