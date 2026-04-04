# frozen_string_literal: true

module Philiprehberger
  module ImageSize
    # Core detection logic that reads minimal bytes from image file headers
    # to determine format and dimensions without decoding the full image.
    module Detector
      SOF_MARKERS = [0xFFC0, 0xFFC2].freeze
      PNG_SIGNATURE = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack('C8').freeze
      JPEG_SIGNATURE = [0xFF, 0xD8].pack('C2').freeze
      TIFF_LE_SIGNATURE = 'II'
      TIFF_BE_SIGNATURE = 'MM'

      class << self
        # Detect image format and dimensions from an IO-like object
        #
        # @param io [IO, StringIO] an IO object positioned at the start
        # @return [ImageInfo, nil] image info or nil if format is unrecognized
        def detect(io)
          header = io.read(64)
          return nil if header.nil? || header.length < 8

          header.force_encoding('BINARY')

          detect_png(io, header) ||
            detect_jpeg(io, header) ||
            detect_gif(io, header) ||
            detect_bmp(header) ||
            detect_webp(io, header) ||
            detect_tiff(io, header) ||
            detect_ico_cur(header) ||
            detect_avif(io, header) ||
            detect_svg(io, header)
        end

        private

        # PNG: 8-byte signature followed by IHDR chunk containing width and height
        # Animation: check for acTL chunk after IHDR
        # Alpha: color type byte (offset 25): types 4 (greyscale+alpha) and 6 (RGBA)
        # Color depth: bit_depth * channels (derived from color type)
        # DPI: from pHYs chunk if unit is meters
        def detect_png(io, header)
          return nil unless header.start_with?(PNG_SIGNATURE)
          return nil if header.length < 29

          width = header[16, 4].unpack1('N')
          height = header[20, 4].unpack1('N')
          bit_depth = header[24].ord
          color_type = header[25].ord

          alpha = [4, 6].include?(color_type)
          channels = png_channels(color_type)
          color_depth = bit_depth * channels

          animated, dpi = png_scan_chunks(io)

          ImageInfo.new(width: width, height: height, format: :png, animated: animated, alpha: alpha,
                        color_depth: color_depth, dpi: dpi)
        end

        # Return number of channels for a PNG color type
        def png_channels(color_type)
          case color_type
          when 0 then 1 # greyscale
          when 2 then 3 # RGB
          when 3 then 1 # indexed (palette)
          when 4 then 2 # greyscale + alpha
          when 6 then 4 # RGBA
          else 1
          end
        end

        # Scan PNG chunks after IHDR for acTL (animation) and pHYs (DPI)
        # Returns [animated, dpi]
        def png_scan_chunks(io)
          animated = false
          dpi = nil

          io.seek(8) # skip PNG signature
          loop do
            chunk_header = io.read(8)
            break if chunk_header.nil? || chunk_header.length < 8

            chunk_length = chunk_header[0, 4].unpack1('N')
            chunk_type = chunk_header[4, 4]

            case chunk_type
            when 'acTL'
              animated = true
              io.seek(chunk_length + 4, IO::SEEK_CUR)
            when 'pHYs'
              dpi = parse_png_phys(io, chunk_length)
            when 'IDAT'
              break
            else
              io.seek(chunk_length + 4, IO::SEEK_CUR)
            end
          end

          [animated, dpi]
        rescue StandardError
          [false, nil]
        end

        # Parse pHYs chunk: 4-byte X ppu, 4-byte Y ppu, 1-byte unit (1=meter)
        def parse_png_phys(io, chunk_length)
          data = io.read(chunk_length)
          io.read(4) # CRC
          return nil if data.nil? || data.length < 9

          ppu_x = data[0, 4].unpack1('N')
          ppu_y = data[4, 4].unpack1('N')
          unit = data[8].ord

          # Unit 1 = pixels per meter; convert to DPI (1 inch = 0.0254 m)
          return nil unless unit == 1 && ppu_x.positive? && ppu_y.positive?

          { x: (ppu_x * 0.0254).round(2), y: (ppu_y * 0.0254).round(2) }
        end

        # JPEG: Starts with FF D8, dimensions in SOF0 (FF C0) or SOF2 (FF C2) marker
        # Also checks for EXIF orientation and JFIF APP0 DPI
        def detect_jpeg(io, header)
          return nil unless header[0, 2] == JPEG_SIGNATURE

          io.seek(2)
          orientation = nil
          width = nil
          height = nil
          dpi = nil

          loop do
            marker = read_jpeg_marker(io)
            break if marker.nil?

            if marker == 0xFFE0 && dpi.nil?
              dpi = read_jfif_dpi(io)
              next
            end

            if marker == 0xFFE1 && orientation.nil?
              orientation = read_exif_orientation(io)
              next
            end

            if SOF_MARKERS.include?(marker)
              data = io.read(7)
              break if data.nil? || data.length < 7

              height = data[3, 2].unpack1('n')
              width = data[5, 2].unpack1('n')
              break
            end

            break unless skip_jpeg_segment(io)
          end

          return nil if width.nil? || height.nil?

          # Swap dimensions for orientations 5-8 (rotated 90/270 degrees)
          if orientation && orientation >= 5 && orientation <= 8
            width, height = height, width
          end

          ImageInfo.new(width: width, height: height, format: :jpeg, orientation: orientation, dpi: dpi)
        end

        # Read DPI from JFIF APP0 segment
        def read_jfif_dpi(io)
          length_bytes = io.read(2)
          return nil if length_bytes.nil? || length_bytes.length < 2

          length = length_bytes.unpack1('n')
          return nil if length < 14

          data = io.read(length - 2)
          return nil if data.nil? || data.length < 12

          # Check for "JFIF\0" identifier
          return nil unless data[0, 5] == "JFIF\x00"

          units = data[7].ord
          x_density = data[8, 2].unpack1('n')
          y_density = data[10, 2].unpack1('n')

          return nil unless x_density.positive? && y_density.positive?

          case units
          when 1 # dots per inch
            { x: x_density.to_f, y: y_density.to_f }
          when 2 # dots per centimeter -> convert to DPI
            { x: (x_density * 2.54).round(2), y: (y_density * 2.54).round(2) }
          end
        end

        # Read EXIF orientation from APP1 segment
        def read_exif_orientation(io)
          length_bytes = io.read(2)
          return nil if length_bytes.nil? || length_bytes.length < 2

          length = length_bytes.unpack1('n')
          return nil if length < 8

          data = io.read(length - 2)
          return nil if data.nil? || data.length < 6

          # Check for "Exif\0\0" header
          return nil unless data[0, 6] == "Exif\x00\x00"

          tiff_data = data[6..]
          return nil if tiff_data.nil? || tiff_data.length < 8

          parse_exif_orientation(tiff_data)
        end

        # Parse TIFF/EXIF IFD to find orientation tag (0x0112 = 274)
        def parse_exif_orientation(tiff_data)
          byte_order = tiff_data[0, 2]
          if byte_order == 'II'
            unpack_16 = 'v'
            unpack_32 = 'V'
          elsif byte_order == 'MM'
            unpack_16 = 'n'
            unpack_32 = 'N'
          else
            return nil
          end

          ifd_offset = tiff_data[4, 4].unpack1(unpack_32)
          return nil if ifd_offset.nil? || ifd_offset + 2 > tiff_data.length

          entry_count = tiff_data[ifd_offset, 2].unpack1(unpack_16)
          return nil if entry_count.nil?

          entry_count.times do |i|
            entry_start = ifd_offset + 2 + (i * 12)
            break if entry_start + 12 > tiff_data.length

            tag = tiff_data[entry_start, 2].unpack1(unpack_16)
            next unless tag == 0x0112

            value = tiff_data[entry_start + 8, 2].unpack1(unpack_16)
            return value if value && value >= 1 && value <= 8
          end

          nil
        end

        # Read a 2-byte JPEG marker from the IO
        def read_jpeg_marker(io)
          bytes = io.read(2)
          return nil if bytes.nil? || bytes.length < 2

          bytes.unpack1('n')
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
        # Animation: check for NETSCAPE2.0 application extension
        # Alpha: check for transparent color index in Graphics Control Extension
        def detect_gif(io, header)
          return nil unless header.start_with?('GIF87a') || header.start_with?('GIF89a')
          return nil if header.length < 10

          width = header[6, 2].unpack1('v')
          height = header[8, 2].unpack1('v')

          animated = false
          alpha = false

          if header.start_with?('GIF89a')
            animated, alpha = gif_scan_extensions(io)
          end

          ImageInfo.new(width: width, height: height, format: :gif, animated: animated, alpha: alpha)
        end

        # Scan GIF data blocks for NETSCAPE2.0 (animation) and GCE transparency
        def gif_scan_extensions(io)
          # Skip past header (6) + logical screen descriptor (7) + optional GCT
          io.seek(6)
          lsd = io.read(7)
          return [false, false] if lsd.nil? || lsd.length < 7

          # Check if Global Color Table exists
          packed = lsd[4].ord
          gct_flag = (packed >> 7) & 1
          if gct_flag == 1
            gct_size = 3 * (1 << ((packed & 0x07) + 1))
            io.seek(gct_size, IO::SEEK_CUR)
          end

          animated = false
          alpha = false

          loop do
            introducer = io.read(1)
            break if introducer.nil? || introducer.empty?

            byte = introducer.ord

            case byte
            when 0x21 # Extension
              label = io.read(1)
              break if label.nil? || label.empty?

              label_byte = label.ord

              if label_byte == 0xF9 # Graphics Control Extension
                block_size = io.read(1)
                break if block_size.nil?

                gce_data = io.read(block_size.ord)
                break if gce_data.nil? || gce_data.length < 4

                gce_packed = gce_data[0].ord
                transparent_flag = gce_packed & 0x01
                alpha = true if transparent_flag == 1

                # Skip block terminator
                io.read(1)
              elsif label_byte == 0xFF # Application Extension
                block_size = io.read(1)
                break if block_size.nil?

                app_data = io.read(block_size.ord)
                break if app_data.nil?

                if app_data.length >= 11 && app_data[0, 11] == 'NETSCAPE2.0'
                  animated = true
                end

                # Skip sub-blocks
                skip_gif_sub_blocks(io)
              else
                # Skip sub-blocks for other extensions
                skip_gif_sub_blocks(io)
              end
            when 0x2C # Image Descriptor - stop scanning extensions
              break
            when 0x3B # Trailer
              break
            else
              break
            end
          end

          [animated, alpha]
        rescue StandardError
          [false, false]
        end

        # Skip GIF sub-blocks until block terminator (0x00)
        def skip_gif_sub_blocks(io)
          loop do
            size_byte = io.read(1)
            return if size_byte.nil? || size_byte.empty?

            size = size_byte.ord
            return if size.zero?

            io.seek(size, IO::SEEK_CUR)
          end
        end

        # BMP: Starts with "BM", width at bytes 18-21 and height at bytes 22-25 (little-endian, signed)
        # Color depth at bytes 28-29 (bits per pixel)
        # DPI from X/Y pixels per meter at bytes 38-45
        def detect_bmp(header)
          return nil unless header.start_with?('BM')
          return nil if header.length < 26

          width = header[18, 4].unpack1('V')
          height = header[22, 4].unpack1('l<').abs

          color_depth = header.length >= 30 ? header[28, 2].unpack1('v') : nil

          dpi = nil
          if header.length >= 46
            ppm_x = header[38, 4].unpack1('V')
            ppm_y = header[42, 4].unpack1('V')
            if ppm_x.positive? && ppm_y.positive?
              dpi = { x: (ppm_x * 0.0254).round(2), y: (ppm_y * 0.0254).round(2) }
            end
          end

          ImageInfo.new(width: width, height: height, format: :bmp, color_depth: color_depth, dpi: dpi)
        end

        # WebP: Starts with "RIFF" + 4 bytes size + "WEBP"
        # Animation: VP8X with ANIM chunk, or check flags
        # Alpha: VP8L has alpha bit, VP8X has alpha flag
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
          when 'VP8X' then detect_webp_vp8x(io, header)
          end
        end

        # VP8 (lossy): dimensions at bytes 26-29 (little-endian, masked to 14 bits)
        def detect_webp_vp8(header)
          return nil if header.length < 30

          width = header[26, 2].unpack1('v') & 0x3FFF
          height = header[28, 2].unpack1('v') & 0x3FFF

          ImageInfo.new(width: width, height: height, format: :webp, alpha: false, animated: false)
        end

        # VP8L (lossless): dimensions packed into 4 bytes at offset 21
        # Alpha: bit at position 28 of the 32-bit value at offset 21
        def detect_webp_vp8l(header)
          return nil if header.length < 25

          bits = header[21, 4].unpack1('V')
          width = (bits & 0x3FFF) + 1
          height = ((bits >> 14) & 0x3FFF) + 1
          alpha = (bits >> 28).allbits?(0x01)

          ImageInfo.new(width: width, height: height, format: :webp, alpha: alpha, animated: false)
        end

        # VP8X (extended): canvas dimensions at bytes 24-29 (24-bit LE + 1)
        # Flags byte at offset 20: bit 4 = alpha, bit 1 = animation
        def detect_webp_vp8x(io, header)
          io.seek(20)
          flags_byte = io.read(1)
          return nil if flags_byte.nil?

          flags = flags_byte.ord
          alpha = flags.anybits?(0x10)
          animated = flags.anybits?(0x02)

          io.seek(24)
          data = io.read(6)
          return nil if data.nil? || data.length < 6

          width = unpack_24bit_le(data, 0) + 1
          height = unpack_24bit_le(data, 3) + 1

          ImageInfo.new(width: width, height: height, format: :webp, alpha: alpha, animated: animated)
        end

        # Unpack a 24-bit little-endian integer from data at given offset
        def unpack_24bit_le(data, offset)
          data[offset].ord | (data[offset + 1].ord << 8) | (data[offset + 2].ord << 16)
        end

        # TIFF: Starts with "II" (little-endian) or "MM" (big-endian) + magic 42
        # Read IFD entries for ImageWidth (256), ImageLength (257),
        # XResolution (282), YResolution (283), and ResolutionUnit (296)
        def detect_tiff(io, header)
          return nil if header.length < 8

          byte_order = header[0, 2]
          return nil unless [TIFF_LE_SIGNATURE, TIFF_BE_SIGNATURE].include?(byte_order)

          if byte_order == TIFF_LE_SIGNATURE
            unpack_16 = 'v'
            unpack_32 = 'V'
          else
            unpack_16 = 'n'
            unpack_32 = 'N'
          end

          magic = header[2, 2].unpack1(unpack_16)
          return nil unless magic == 42

          ifd_offset = header[4, 4].unpack1(unpack_32)
          io.seek(ifd_offset)

          entry_count_data = io.read(2)
          return nil if entry_count_data.nil? || entry_count_data.length < 2

          entry_count = entry_count_data.unpack1(unpack_16)
          width = nil
          height = nil
          res_unit = 2 # default: inches
          x_res_offset = nil
          y_res_offset = nil

          entry_count.times do
            entry = io.read(12)
            break if entry.nil? || entry.length < 12

            tag = entry[0, 2].unpack1(unpack_16)
            type = entry[2, 2].unpack1(unpack_16)

            value = if type == 3 # SHORT
                      entry[8, 2].unpack1(unpack_16)
                    else # LONG or other
                      entry[8, 4].unpack1(unpack_32)
                    end

            case tag
            when 256 then width = value
            when 257 then height = value
            when 282 then x_res_offset = entry[8, 4].unpack1(unpack_32) # RATIONAL offset
            when 283 then y_res_offset = entry[8, 4].unpack1(unpack_32) # RATIONAL offset
            when 296 then res_unit = value
            end
          end

          return nil if width.nil? || height.nil?

          dpi = tiff_extract_dpi(io, x_res_offset, y_res_offset, res_unit, unpack_32)

          ImageInfo.new(width: width, height: height, format: :tiff, dpi: dpi)
        end

        # Read TIFF RATIONAL values (numerator/denominator) for DPI
        def tiff_extract_dpi(io, x_res_offset, y_res_offset, res_unit, unpack_32)
          return nil if x_res_offset.nil? || y_res_offset.nil?

          x_dpi = tiff_read_rational(io, x_res_offset, unpack_32)
          y_dpi = tiff_read_rational(io, y_res_offset, unpack_32)
          return nil if x_dpi.nil? || y_dpi.nil?

          # ResolutionUnit: 2=inches, 3=centimeters
          case res_unit
          when 2
            { x: x_dpi.round(2), y: y_dpi.round(2) }
          when 3
            { x: (x_dpi * 2.54).round(2), y: (y_dpi * 2.54).round(2) }
          end
        end

        # Read a TIFF RATIONAL (two 32-bit unsigned ints) at an offset
        def tiff_read_rational(io, offset, unpack_32)
          io.seek(offset)
          data = io.read(8)
          return nil if data.nil? || data.length < 8

          num = data[0, 4].unpack1(unpack_32)
          den = data[4, 4].unpack1(unpack_32)
          return nil if den.zero?

          num.to_f / den
        end

        # ICO/CUR: 2-byte reserved (0), 2-byte type (1=ICO, 2=CUR), 2-byte count
        # First directory entry: 1-byte width, 1-byte height (0 means 256)
        def detect_ico_cur(header)
          return nil if header.length < 22

          reserved = header[0, 2].unpack1('v')
          return nil unless reserved.zero?

          type = header[2, 2].unpack1('v')
          return nil unless [1, 2].include?(type)

          count = header[4, 2].unpack1('v')
          return nil if count.zero?

          # First directory entry starts at offset 6
          w = header[6].ord
          h = header[7].ord
          width = w.zero? ? 256 : w
          height = h.zero? ? 256 : h

          fmt = type == 1 ? :ico : :cur

          ImageInfo.new(width: width, height: height, format: fmt, alpha: true)
        end

        # AVIF: ISOBMFF container with ftyp box containing 'avif' or 'avis' brand
        # Dimensions from ispe (ImageSpatialExtentsProperty) box
        def detect_avif(io, header)
          return nil if header.length < 12

          # Check for ftyp box
          box_size = header[0, 4].unpack1('N')
          box_type = header[4, 4]
          return nil unless box_type == 'ftyp'

          # Read ftyp content for brand check
          return nil if box_size < 12

          brand = header[8, 4]
          return nil unless avif_brand?(brand, header, box_size)

          # Scan for ispe box to get dimensions
          io.seek(0)
          file_data = io.read(4096)
          return nil if file_data.nil?

          find_avif_ispe(file_data)
        end

        def avif_brand?(major_brand, header, box_size)
          return true if %w[avif avis].include?(major_brand)

          # Check compatible brands
          offset = 16
          while offset + 4 <= box_size && offset + 4 <= header.length
            compat = header[offset, 4]
            return true if %w[avif avis].include?(compat)

            offset += 4
          end

          false
        end

        # Search for ispe box in AVIF data (4-byte width + 4-byte height, both big-endian)
        def find_avif_ispe(data)
          idx = 0
          while idx + 12 <= data.length
            if data[idx, 4] == 'ispe'
              # ispe box: 4-byte type + 1-byte version + 3-byte flags + 4-byte width + 4-byte height
              ispe_start = idx + 4 # skip "ispe"
              return nil if ispe_start + 12 > data.length

              width = data[ispe_start + 4, 4].unpack1('N')
              height = data[ispe_start + 8, 4].unpack1('N')

              return ImageInfo.new(width: width, height: height, format: :avif) if width&.positive? && height&.positive?
            end
            idx += 1
          end

          nil
        end

        # SVG: XML-based, look for <svg tag with width/height or viewBox attributes
        def detect_svg(io, header)
          # Read enough data to find full <svg ...> tag
          io.seek(0)
          text = io.read(4096)
          return nil if text.nil?

          text = text.force_encoding('UTF-8')
          return nil unless text.include?('<svg')

          # Extract the <svg ... > opening tag
          svg_match = text.match(/<svg[^>]*>/m)
          return nil unless svg_match

          svg_tag = svg_match[0]
          parse_svg_dimensions(svg_tag)
        end

        def parse_svg_dimensions(svg_tag)
          width = extract_svg_length(svg_tag, 'width')
          height = extract_svg_length(svg_tag, 'height')

          if width && height
            return ImageInfo.new(width: width.to_i, height: height.to_i, format: :svg)
          end

          # Fall back to viewBox
          viewbox_match = svg_tag.match(/viewBox\s*=\s*["']([^"']+)["']/)
          if viewbox_match
            parts = viewbox_match[1].strip.split(/[\s,]+/)
            if parts.length >= 4
              vb_width = parts[2].to_f
              vb_height = parts[3].to_f
              if vb_width.positive? && vb_height.positive?
                return ImageInfo.new(width: vb_width.to_i, height: vb_height.to_i, format: :svg)
              end
            end
          end

          nil
        end

        # Extract numeric dimension from SVG attribute (supports px, pt, bare numbers)
        def extract_svg_length(svg_tag, attr)
          match = svg_tag.match(/\b#{attr}\s*=\s*["']([^"']+)["']/)
          return nil unless match

          value = match[1].strip
          # Extract numeric value, ignoring units like px, pt, em, etc.
          num_match = value.match(/^(\d+(?:\.\d+)?)/)
          return nil unless num_match

          num_match[1].to_f
        end
      end
    end
  end
end
