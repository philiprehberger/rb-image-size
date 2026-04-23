# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Philiprehberger::ImageSize do
  it 'has a version number' do
    expect(Philiprehberger::ImageSize::VERSION).not_to be_nil
  end

  describe '.of' do
    context 'with PNG' do
      it 'detects dimensions and format from a minimal PNG' do
        png = [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, # PNG signature
          0x00, 0x00, 0x00, 0x0D,                           # IHDR chunk length (13)
          0x49, 0x48, 0x44, 0x52,                           # "IHDR"
          0x00, 0x00, 0x00, 0x80,                           # width = 128
          0x00, 0x00, 0x00, 0x40,                           # height = 64
          0x08, 0x02, 0x00, 0x00, 0x00,                     # bit depth=8, color type=2 (RGB), compression, filter, interlace
          0x00, 0x00, 0x00, 0x00                            # CRC placeholder
        ].pack('C*')
        # Add IDAT chunk to stop scanning
        png += "#{[0x00, 0x00, 0x00, 0x00].pack('N')}IDAT#{[0x00, 0x00, 0x00, 0x00].pack('N')}"

        io = StringIO.new(png)
        info = described_class.of(io)

        expect(info.width).to eq(128)
        expect(info.height).to eq(64)
        expect(info.format).to eq(:png)
        expect(info.alpha?).to be false
        expect(info.animated?).to be false
      end

      it 'detects alpha channel for RGBA PNG (color type 6)' do
        png = [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x80,
          0x00, 0x00, 0x00, 0x40,
          0x08, 0x06, 0x00, 0x00, 0x00,                     # color type=6 (RGBA)
          0x00, 0x00, 0x00, 0x00
        ].pack('C*')
        png += "#{[0x00, 0x00, 0x00, 0x00].pack('N')}IDAT#{[0x00, 0x00, 0x00, 0x00].pack('N')}"

        io = StringIO.new(png)
        info = described_class.of(io)

        expect(info.alpha?).to be true
      end

      it 'detects alpha channel for greyscale+alpha PNG (color type 4)' do
        png = [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x10,
          0x00, 0x00, 0x00, 0x10,
          0x08, 0x04, 0x00, 0x00, 0x00,                     # color type=4 (greyscale+alpha)
          0x00, 0x00, 0x00, 0x00
        ].pack('C*')
        png += "#{[0x00, 0x00, 0x00, 0x00].pack('N')}IDAT#{[0x00, 0x00, 0x00, 0x00].pack('N')}"

        io = StringIO.new(png)
        info = described_class.of(io)

        expect(info.alpha?).to be true
      end

      it 'detects APNG animation via acTL chunk' do
        png = [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x20,                           # width = 32
          0x00, 0x00, 0x00, 0x20,                           # height = 32
          0x08, 0x02, 0x00, 0x00, 0x00,                     # color type=2 (RGB)
          0x00, 0x00, 0x00, 0x00                            # CRC placeholder
        ].pack('C*')
        # acTL chunk (animation control): 8 bytes data
        png += "#{[0x00, 0x00, 0x00, 0x08].pack('N')}acTL"
        png += [0x00, 0x00, 0x00, 0x03].pack('N') # num_frames = 3
        png += [0x00, 0x00, 0x00, 0x00].pack('N') # num_plays = 0 (infinite)
        png += [0x00, 0x00, 0x00, 0x00].pack('N') # CRC

        io = StringIO.new(png)
        info = described_class.of(io)

        expect(info.animated?).to be true
        expect(info.width).to eq(32)
        expect(info.height).to eq(32)
      end

      it 'reports non-animated PNG without acTL' do
        png = [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x10,
          0x00, 0x00, 0x00, 0x10,
          0x08, 0x02, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00
        ].pack('C*')
        png += "#{[0x00, 0x00, 0x00, 0x00].pack('N')}IDAT#{[0x00, 0x00, 0x00, 0x00].pack('N')}"

        io = StringIO.new(png)
        info = described_class.of(io)

        expect(info.animated?).to be false
      end
    end

    context 'with JPEG' do
      it 'detects dimensions and format from a minimal JPEG with SOF0' do
        jpeg = [
          0xFF, 0xD8,                         # SOI
          0xFF, 0xE0,                         # APP0 marker
          0x00, 0x02,                         # APP0 length (2 = just the length field, minimal)
          0xFF, 0xC0,                         # SOF0 marker
          0x00, 0x0B,                         # SOF0 length (11)
          0x08,                               # precision (8 bits)
          0x02, 0x00,                         # height = 512
          0x01, 0x00,                         # width = 256
          0x03,                               # number of components
          0x01, 0x11, 0x00,                   # component 1
          0x02, 0x11, 0x01                    # component 2
        ].pack('C*')

        io = StringIO.new(jpeg)
        info = described_class.of(io)

        expect(info.width).to eq(256)
        expect(info.height).to eq(512)
        expect(info.format).to eq(:jpeg)
      end

      it 'detects dimensions from SOF2 (progressive JPEG)' do
        jpeg = [
          0xFF, 0xD8,
          0xFF, 0xC2,                         # SOF2 marker (progressive)
          0x00, 0x0B,
          0x08,
          0x01, 0x90,                         # height = 400
          0x00, 0xC8,                         # width = 200
          0x03,
          0x01, 0x11, 0x00,
          0x02, 0x11, 0x01
        ].pack('C*')

        io = StringIO.new(jpeg)
        info = described_class.of(io)

        expect(info.width).to eq(200)
        expect(info.height).to eq(400)
        expect(info.format).to eq(:jpeg)
      end

      it 'detects EXIF orientation and swaps dimensions for rotation' do
        # Build JPEG with APP1/EXIF containing orientation=6 (rotated 90 CW)
        # then SOF0 with width=200, height=400 (stored dimensions)
        exif_data = build_exif_with_orientation(6)
        app1_length = exif_data.length + 2

        jpeg = [0xFF, 0xD8].pack('C*') # SOI
        jpeg += [0xFF, 0xE1].pack('C*') # APP1
        jpeg += [app1_length].pack('n') # APP1 length
        jpeg += exif_data
        jpeg += [0xFF, 0xC0].pack('C*')           # SOF0
        jpeg += [0x00, 0x0B].pack('C*')           # length
        jpeg += [0x08].pack('C')                   # precision
        jpeg += [400].pack('n')                    # height = 400 (stored)
        jpeg += [200].pack('n')                    # width = 200 (stored)
        jpeg += [0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01].pack('C*')

        io = StringIO.new(jpeg)
        info = described_class.of(io)

        expect(info.orientation).to eq(6)
        # Orientation 6 means rotated 90 CW, so display dimensions swap
        expect(info.width).to eq(400)
        expect(info.height).to eq(200)
      end

      it 'does not swap dimensions for orientation 1 (normal)' do
        exif_data = build_exif_with_orientation(1)
        app1_length = exif_data.length + 2

        jpeg = [0xFF, 0xD8].pack('C*')
        jpeg += [0xFF, 0xE1].pack('C*')
        jpeg += [app1_length].pack('n')
        jpeg += exif_data
        jpeg += [0xFF, 0xC0].pack('C*')
        jpeg += [0x00, 0x0B].pack('C*')
        jpeg += [0x08].pack('C')
        jpeg += [400].pack('n')                    # height
        jpeg += [200].pack('n')                    # width
        jpeg += [0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01].pack('C*')

        io = StringIO.new(jpeg)
        info = described_class.of(io)

        expect(info.orientation).to eq(1)
        expect(info.width).to eq(200)
        expect(info.height).to eq(400)
      end

      it 'swaps dimensions for orientation 8 (rotated 270 CW)' do
        exif_data = build_exif_with_orientation(8)
        app1_length = exif_data.length + 2

        jpeg = [0xFF, 0xD8].pack('C*')
        jpeg += [0xFF, 0xE1].pack('C*')
        jpeg += [app1_length].pack('n')
        jpeg += exif_data
        jpeg += [0xFF, 0xC0].pack('C*')
        jpeg += [0x00, 0x0B].pack('C*')
        jpeg += [0x08].pack('C')
        jpeg += [300].pack('n')                    # height = 300 (stored)
        jpeg += [100].pack('n')                    # width = 100 (stored)
        jpeg += [0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01].pack('C*')

        io = StringIO.new(jpeg)
        info = described_class.of(io)

        expect(info.orientation).to eq(8)
        expect(info.width).to eq(300)
        expect(info.height).to eq(100)
      end

      it 'returns nil orientation when no EXIF data' do
        jpeg = [
          0xFF, 0xD8,
          0xFF, 0xC0,
          0x00, 0x0B,
          0x08,
          0x01, 0x90,
          0x00, 0xC8,
          0x03,
          0x01, 0x11, 0x00,
          0x02, 0x11, 0x01
        ].pack('C*')

        io = StringIO.new(jpeg)
        info = described_class.of(io)

        expect(info.orientation).to be_nil
      end
    end

    context 'with GIF' do
      it 'detects dimensions from GIF89a' do
        gif = "GIF89a#{[320, 240].pack('vv')}#{"\x00" * 4}"

        io = StringIO.new(gif)
        info = described_class.of(io)

        expect(info.width).to eq(320)
        expect(info.height).to eq(240)
        expect(info.format).to eq(:gif)
      end

      it 'detects dimensions from GIF87a' do
        gif = "GIF87a#{[100, 50].pack('vv')}#{"\x00" * 4}"

        io = StringIO.new(gif)
        info = described_class.of(io)

        expect(info.width).to eq(100)
        expect(info.height).to eq(50)
        expect(info.format).to eq(:gif)
      end

      it 'detects animated GIF with NETSCAPE2.0 extension' do
        gif = build_animated_gif(320, 240)

        io = StringIO.new(gif)
        info = described_class.of(io)

        expect(info.animated?).to be true
        expect(info.width).to eq(320)
        expect(info.height).to eq(240)
      end

      it 'detects non-animated GIF89a' do
        # GIF89a without NETSCAPE2.0 extension, just image descriptor
        gif = 'GIF89a'
        gif += [100, 50].pack('vv')          # width, height
        gif += [0x00, 0x00, 0x00].pack('C3') # packed, bg color, aspect ratio
        gif += [0x2C].pack('C')              # Image descriptor introducer
        gif += "\x00" * 20                   # padding

        io = StringIO.new(gif)
        info = described_class.of(io)

        expect(info.animated?).to be false
      end

      it 'detects GIF transparency via GCE' do
        gif = build_gif_with_transparency(64, 64)

        io = StringIO.new(gif)
        info = described_class.of(io)

        expect(info.alpha?).to be true
      end

      it 'reports no alpha for GIF without transparency' do
        # GIF89a without GCE, just image descriptor
        gif = 'GIF89a'
        gif += [64, 64].pack('vv')
        gif += [0x00, 0x00, 0x00].pack('C3')
        gif += [0x2C].pack('C') # Image descriptor
        gif += "\x00" * 20

        io = StringIO.new(gif)
        info = described_class.of(io)

        expect(info.alpha?).to be false
      end
    end

    context 'with BMP' do
      it 'detects dimensions from a BMP header' do
        bmp = 'BM'
        bmp += [0].pack('V')
        bmp += [0].pack('V')
        bmp += [54].pack('V')
        bmp += [40].pack('V')
        bmp += [640].pack('V')
        bmp += [480].pack('l<')

        io = StringIO.new(bmp)
        info = described_class.of(io)

        expect(info.width).to eq(640)
        expect(info.height).to eq(480)
        expect(info.format).to eq(:bmp)
      end

      it 'handles top-down BMP (negative height)' do
        bmp = 'BM'
        bmp += [0].pack('V')
        bmp += [0].pack('V')
        bmp += [54].pack('V')
        bmp += [40].pack('V')
        bmp += [800].pack('V')
        bmp += [-600].pack('l<')

        io = StringIO.new(bmp)
        info = described_class.of(io)

        expect(info.width).to eq(800)
        expect(info.height).to eq(600)
        expect(info.format).to eq(:bmp)
      end
    end

    context 'with WebP' do
      it 'detects dimensions from VP8 (lossy) WebP' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8 '
        webp += [30].pack('V')
        webp += [0x00, 0x00, 0x00].pack('C3')
        webp += [0x9D, 0x01, 0x2A].pack('C3')
        webp += [320].pack('v')
        webp += [240].pack('v')
        webp += "\x00" * 10

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.width).to eq(320)
        expect(info.height).to eq(240)
        expect(info.format).to eq(:webp)
        expect(info.alpha?).to be false
        expect(info.animated?).to be false
      end

      it 'detects dimensions from VP8L (lossless) WebP' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8L'
        webp += [20].pack('V')
        webp += [0x2F].pack('C')

        # width=256 -> 255, height=128 -> 127
        bits = (127 << 14) | 255
        webp += [bits].pack('V')
        webp += "\x00" * 10

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.width).to eq(256)
        expect(info.height).to eq(128)
        expect(info.format).to eq(:webp)
      end

      it 'detects alpha in VP8L WebP' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8L'
        webp += [20].pack('V')
        webp += [0x2F].pack('C')

        # Set alpha bit (bit 28) + width=255, height=127
        bits = (1 << 28) | (127 << 14) | 255
        webp += [bits].pack('V')
        webp += "\x00" * 10

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.alpha?).to be true
      end

      it 'detects no alpha in VP8L WebP without alpha bit' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8L'
        webp += [20].pack('V')
        webp += [0x2F].pack('C')

        bits = (127 << 14) | 255
        webp += [bits].pack('V')
        webp += "\x00" * 10

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.alpha?).to be false
      end

      it 'detects dimensions from VP8X (extended) WebP' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8X'
        webp += [10].pack('V')
        webp += [0x00, 0x00, 0x00, 0x00].pack('C4')

        w_raw = 1023
        h_raw = 767
        webp += [w_raw & 0xFF, (w_raw >> 8) & 0xFF, (w_raw >> 16) & 0xFF].pack('C3')
        webp += [h_raw & 0xFF, (h_raw >> 8) & 0xFF, (h_raw >> 16) & 0xFF].pack('C3')

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.width).to eq(1024)
        expect(info.height).to eq(768)
        expect(info.format).to eq(:webp)
      end

      it 'detects animated WebP via VP8X flags' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8X'
        webp += [10].pack('V')
        # Flags: bit 1 = animation (0x02)
        webp += [0x02, 0x00, 0x00, 0x00].pack('C4')

        w_raw = 99
        h_raw = 99
        webp += [w_raw & 0xFF, (w_raw >> 8) & 0xFF, (w_raw >> 16) & 0xFF].pack('C3')
        webp += [h_raw & 0xFF, (h_raw >> 8) & 0xFF, (h_raw >> 16) & 0xFF].pack('C3')

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.animated?).to be true
        expect(info.width).to eq(100)
        expect(info.height).to eq(100)
      end

      it 'detects alpha in VP8X WebP' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8X'
        webp += [10].pack('V')
        # Flags: bit 4 = alpha (0x10)
        webp += [0x10, 0x00, 0x00, 0x00].pack('C4')

        w_raw = 99
        h_raw = 99
        webp += [w_raw & 0xFF, (w_raw >> 8) & 0xFF, (w_raw >> 16) & 0xFF].pack('C3')
        webp += [h_raw & 0xFF, (h_raw >> 8) & 0xFF, (h_raw >> 16) & 0xFF].pack('C3')

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.alpha?).to be true
      end

      it 'detects non-animated non-alpha VP8X WebP' do
        webp = 'RIFF'
        webp += [100].pack('V')
        webp += 'WEBP'
        webp += 'VP8X'
        webp += [10].pack('V')
        webp += [0x00, 0x00, 0x00, 0x00].pack('C4')

        w_raw = 99
        h_raw = 99
        webp += [w_raw & 0xFF, (w_raw >> 8) & 0xFF, (w_raw >> 16) & 0xFF].pack('C3')
        webp += [h_raw & 0xFF, (h_raw >> 8) & 0xFF, (h_raw >> 16) & 0xFF].pack('C3')

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.animated?).to be false
        expect(info.alpha?).to be false
      end
    end

    context 'with TIFF' do
      it 'detects dimensions from little-endian TIFF' do
        tiff = 'II'                              # Little-endian
        tiff += [42].pack('v')                   # Magic number
        tiff += [8].pack('V')                    # IFD offset
        # IFD at offset 8
        tiff += [2].pack('v') # 2 entries
        # Entry 1: ImageWidth (256), SHORT, count=1, value=640
        tiff += [256].pack('v')                  # tag
        tiff += [3].pack('v')                    # type = SHORT
        tiff += [1].pack('V')                    # count
        tiff += "#{[640].pack('v')}\u0000\u0000" # value (padded to 4 bytes)
        # Entry 2: ImageLength (257), SHORT, count=1, value=480
        tiff += [257].pack('v')
        tiff += [3].pack('v')
        tiff += [1].pack('V')
        tiff += "#{[480].pack('v')}\u0000\u0000"

        io = StringIO.new(tiff)
        info = described_class.of(io)

        expect(info.width).to eq(640)
        expect(info.height).to eq(480)
        expect(info.format).to eq(:tiff)
      end

      it 'detects dimensions from big-endian TIFF' do
        tiff = 'MM'                              # Big-endian
        tiff += [42].pack('n')                   # Magic number
        tiff += [8].pack('N')                    # IFD offset
        # IFD at offset 8
        tiff += [2].pack('n') # 2 entries
        # Entry 1: ImageWidth (256), LONG, count=1, value=1920
        tiff += [256].pack('n')
        tiff += [4].pack('n') # type = LONG
        tiff += [1].pack('N')
        tiff += [1920].pack('N')
        # Entry 2: ImageLength (257), LONG, count=1, value=1080
        tiff += [257].pack('n')
        tiff += [4].pack('n')
        tiff += [1].pack('N')
        tiff += [1080].pack('N')

        io = StringIO.new(tiff)
        info = described_class.of(io)

        expect(info.width).to eq(1920)
        expect(info.height).to eq(1080)
        expect(info.format).to eq(:tiff)
      end

      it 'handles TIFF with SHORT type for dimensions' do
        tiff = 'II'
        tiff += [42].pack('v')
        tiff += [8].pack('V')
        tiff += [2].pack('v')
        # SHORT type entries
        tiff += "#{[256].pack('v')}#{[3].pack('v')}#{[1].pack('V')}#{[800].pack('v')}\u0000\u0000"
        tiff += "#{[257].pack('v')}#{[3].pack('v')}#{[1].pack('V')}#{[600].pack('v')}\u0000\u0000"

        io = StringIO.new(tiff)
        info = described_class.of(io)

        expect(info.width).to eq(800)
        expect(info.height).to eq(600)
      end
    end

    context 'with ICO' do
      it 'detects dimensions from ICO file' do
        ico = [0].pack('v')                      # Reserved
        ico += [1].pack('v')                     # Type = ICO
        ico += [1].pack('v')                     # Count = 1
        # Directory entry
        ico += [48].pack('C')                    # Width = 48
        ico += [48].pack('C')                    # Height = 48
        ico += "\x00" * 14                       # Rest of directory entry

        io = StringIO.new(ico)
        info = described_class.of(io)

        expect(info.width).to eq(48)
        expect(info.height).to eq(48)
        expect(info.format).to eq(:ico)
        expect(info.alpha?).to be true
      end

      it 'treats 0 dimension as 256 in ICO' do
        ico = [0].pack('v')
        ico += [1].pack('v')                     # Type = ICO
        ico += [1].pack('v')
        ico += [0].pack('C')                     # Width = 0 -> 256
        ico += [0].pack('C')                     # Height = 0 -> 256
        ico += "\x00" * 14

        io = StringIO.new(ico)
        info = described_class.of(io)

        expect(info.width).to eq(256)
        expect(info.height).to eq(256)
        expect(info.format).to eq(:ico)
      end
    end

    context 'with CUR' do
      it 'detects dimensions from CUR file' do
        cur = [0].pack('v')                      # Reserved
        cur += [2].pack('v')                     # Type = CUR
        cur += [1].pack('v')                     # Count = 1
        cur += [32].pack('C')                    # Width = 32
        cur += [32].pack('C')                    # Height = 32
        cur += "\x00" * 14

        io = StringIO.new(cur)
        info = described_class.of(io)

        expect(info.width).to eq(32)
        expect(info.height).to eq(32)
        expect(info.format).to eq(:cur)
      end
    end

    context 'with SVG' do
      it 'detects dimensions from width/height attributes' do
        svg = '<?xml version="1.0"?><svg width="200" height="100" xmlns="http://www.w3.org/2000/svg"></svg>'

        io = StringIO.new(svg)
        info = described_class.of(io)

        expect(info.width).to eq(200)
        expect(info.height).to eq(100)
        expect(info.format).to eq(:svg)
      end

      it 'detects dimensions from viewBox when no width/height' do
        svg = '<svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg"></svg>'

        io = StringIO.new(svg)
        info = described_class.of(io)

        expect(info.width).to eq(400)
        expect(info.height).to eq(300)
        expect(info.format).to eq(:svg)
      end

      it 'handles width/height with px units' do
        svg = '<svg width="150px" height="75px" xmlns="http://www.w3.org/2000/svg"></svg>'

        io = StringIO.new(svg)
        info = described_class.of(io)

        expect(info.width).to eq(150)
        expect(info.height).to eq(75)
        expect(info.format).to eq(:svg)
      end

      it 'handles viewBox with comma separators' do
        svg = '<svg viewBox="0,0,800,600" xmlns="http://www.w3.org/2000/svg"></svg>'

        io = StringIO.new(svg)
        info = described_class.of(io)

        expect(info.width).to eq(800)
        expect(info.height).to eq(600)
        expect(info.format).to eq(:svg)
      end

      it 'prefers width/height over viewBox' do
        svg = '<svg width="100" height="50" viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg"></svg>'

        io = StringIO.new(svg)
        info = described_class.of(io)

        expect(info.width).to eq(100)
        expect(info.height).to eq(50)
      end

      it 'returns nil for non-SVG XML' do
        xml = '<?xml version="1.0"?><html><body>Hello</body></html>'

        io = StringIO.new(xml)
        expect { described_class.of(io) }.to raise_error(Philiprehberger::ImageSize::Error)
      end
    end

    context 'with AVIF' do
      it 'detects dimensions from AVIF with ispe box' do
        avif = build_avif(1920, 1080)

        io = StringIO.new(avif)
        info = described_class.of(io)

        expect(info.width).to eq(1920)
        expect(info.height).to eq(1080)
        expect(info.format).to eq(:avif)
      end

      it 'detects dimensions from small AVIF' do
        avif = build_avif(64, 64)

        io = StringIO.new(avif)
        info = described_class.of(io)

        expect(info.width).to eq(64)
        expect(info.height).to eq(64)
        expect(info.format).to eq(:avif)
      end

      it 'detects AVIF with avis brand' do
        avif = build_avif(320, 240, brand: 'avis')

        io = StringIO.new(avif)
        info = described_class.of(io)

        expect(info.width).to eq(320)
        expect(info.height).to eq(240)
        expect(info.format).to eq(:avif)
      end
    end

    context 'with unrecognized format' do
      it 'raises an error' do
        io = StringIO.new('not an image at all')
        expect { described_class.of(io) }.to raise_error(Philiprehberger::ImageSize::Error, 'Unrecognized image format')
      end
    end

    context 'with empty input' do
      it 'raises an error' do
        io = StringIO.new('')
        expect { described_class.of(io) }.to raise_error(Philiprehberger::ImageSize::Error)
      end
    end
  end

  describe '.dimensions' do
    it 'returns [width, height] array' do
      png = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x01, 0x00,
        0x00, 0x00, 0x00, 0xC8,
        0x08, 0x02, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00
      ].pack('C*')
      png += "#{[0x00, 0x00, 0x00, 0x00].pack('N')}IDAT#{[0x00, 0x00, 0x00, 0x00].pack('N')}"

      expect(described_class.dimensions(StringIO.new(png))).to eq([256, 200])
    end
  end

  describe '.format' do
    it 'returns the format symbol' do
      gif = "GIF89a#{[1, 1].pack('vv')}#{"\x00" * 4}"
      expect(described_class.format(StringIO.new(gif))).to eq(:gif)
    end
  end

  describe Philiprehberger::ImageSize::ImageInfo do
    subject(:info) { described_class.new(width: 800, height: 600, format: :png) }

    describe '#to_a' do
      it 'returns [width, height]' do
        expect(info.to_a).to eq([800, 600])
      end
    end

    describe '#to_h' do
      it 'returns a hash with all attributes' do
        expect(info.to_h).to eq({
                                  width: 800,
                                  height: 600,
                                  format: :png,
                                  animated: false,
                                  alpha: false,
                                  interlaced: false,
                                  orientation: nil,
                                  dpi: nil,
                                  color_depth: nil,
                                  megapixels: 0.5
                                })
      end
    end

    describe '#animated?' do
      it 'returns false by default' do
        expect(info.animated?).to be false
      end

      it 'returns true when animated' do
        animated_info = described_class.new(width: 100, height: 100, format: :gif, animated: true)
        expect(animated_info.animated?).to be true
      end
    end

    describe '#alpha?' do
      it 'returns false by default' do
        expect(info.alpha?).to be false
      end

      it 'returns true when alpha present' do
        alpha_info = described_class.new(width: 100, height: 100, format: :png, alpha: true)
        expect(alpha_info.alpha?).to be true
      end
    end

    describe '#interlaced?' do
      it 'returns false by default' do
        expect(info.interlaced?).to be false
      end

      it 'returns true when interlaced' do
        interlaced_info = described_class.new(width: 100, height: 100, format: :png, interlaced: true)
        expect(interlaced_info.interlaced?).to be true
      end
    end

    describe '#orientation' do
      it 'returns nil by default' do
        expect(info.orientation).to be_nil
      end

      it 'returns orientation value when set' do
        oriented = described_class.new(width: 100, height: 100, format: :jpeg, orientation: 6)
        expect(oriented.orientation).to eq(6)
      end
    end

    describe '#==' do
      it 'considers equal objects with same attributes' do
        other = described_class.new(width: 800, height: 600, format: :png)
        expect(info).to eq(other)
      end

      it 'considers unequal objects with different attributes' do
        other = described_class.new(width: 800, height: 600, format: :jpeg)
        expect(info).not_to eq(other)
      end
    end

    describe '#to_s' do
      it 'returns a human-readable string' do
        expect(info.to_s).to eq('PNG 800x600')
      end
    end

    describe '#inspect' do
      it 'returns an inspect string' do
        expect(info.inspect).to include('format=png')
        expect(info.inspect).to include('width=800')
        expect(info.inspect).to include('height=600')
      end
    end
  end

  describe 'ImageInfo computed properties' do
    describe '#aspect_ratio' do
      it 'returns width divided by height' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 1920, height: 1080, format: :png)
        expect(info.aspect_ratio).to be_within(0.01).of(1.78)
      end

      it 'returns 1.0 for square images' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 100, format: :png)
        expect(info.aspect_ratio).to eq(1.0)
      end

      it 'returns 0.0 when height is zero' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 0, format: :png)
        expect(info.aspect_ratio).to eq(0.0)
      end
    end

    describe '#landscape?' do
      it 'returns true when width > height' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 200, height: 100, format: :png)
        expect(info.landscape?).to be true
      end

      it 'returns false when height > width' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 200, format: :png)
        expect(info.landscape?).to be false
      end

      it 'returns false when equal' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 100, format: :png)
        expect(info.landscape?).to be false
      end
    end

    describe '#portrait?' do
      it 'returns true when height > width' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 200, format: :png)
        expect(info.portrait?).to be true
      end

      it 'returns false when width > height' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 200, height: 100, format: :png)
        expect(info.portrait?).to be false
      end
    end

    describe '#square?' do
      it 'returns true when width equals height' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 100, format: :png)
        expect(info.square?).to be true
      end

      it 'returns false when dimensions differ' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 200, format: :png)
        expect(info.square?).to be false
      end
    end

    describe '#area' do
      it 'returns width times height' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 1920, height: 1080, format: :png)
        expect(info.area).to eq(2_073_600)
      end

      it 'returns 0 when a dimension is zero' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 0, height: 100, format: :png)
        expect(info.area).to eq(0)
      end
    end

    describe '#rotated?' do
      it 'returns true for orientation 5-8' do
        [5, 6, 7, 8].each do |orient|
          info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 200, format: :jpeg, orientation: orient)
          expect(info.rotated?).to be true
        end
      end

      it 'returns false for orientation 1-4' do
        [1, 2, 3, 4].each do |orient|
          info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 200, format: :jpeg, orientation: orient)
          expect(info.rotated?).to be false
        end
      end

      it 'returns false when orientation is nil' do
        info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 200, format: :png)
        expect(info.rotated?).to be false
      end
    end
  end

  describe 'ImageInfo#megapixels' do
    it 'returns megapixels rounded to 1 decimal place' do
      info = Philiprehberger::ImageSize::ImageInfo.new(width: 1920, height: 1080, format: :png)
      expect(info.megapixels).to eq(2.1)
    end

    it 'returns 0.0 for very small images' do
      info = Philiprehberger::ImageSize::ImageInfo.new(width: 10, height: 10, format: :png)
      expect(info.megapixels).to eq(0.0)
    end

    it 'returns correct value for large images' do
      info = Philiprehberger::ImageSize::ImageInfo.new(width: 4000, height: 3000, format: :jpeg)
      expect(info.megapixels).to eq(12.0)
    end
  end

  describe 'ImageInfo#color_depth' do
    it 'returns nil by default' do
      info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 100, format: :jpeg)
      expect(info.color_depth).to be_nil
    end

    it 'returns value when set' do
      info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 100, format: :png, color_depth: 32)
      expect(info.color_depth).to eq(32)
    end

    it 'detects 24-bit color depth for RGB PNG' do
      png = build_png_ihdr(128, 64, bit_depth: 8, color_type: 2) # RGB
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(24) # 8 bits * 3 channels
    end

    it 'detects 32-bit color depth for RGBA PNG' do
      png = build_png_ihdr(128, 64, bit_depth: 8, color_type: 6) # RGBA
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(32) # 8 bits * 4 channels
    end

    it 'detects 8-bit color depth for greyscale PNG' do
      png = build_png_ihdr(16, 16, bit_depth: 8, color_type: 0) # greyscale
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(8) # 8 bits * 1 channel
    end

    it 'detects 16-bit color depth for greyscale+alpha PNG' do
      png = build_png_ihdr(16, 16, bit_depth: 8, color_type: 4) # greyscale+alpha
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(16) # 8 bits * 2 channels
    end

    it 'detects color depth from BMP header' do
      bmp = build_bmp(640, 480, bits_per_pixel: 24)
      io = StringIO.new(bmp)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(24)
    end

    it 'detects 32-bit BMP color depth' do
      bmp = build_bmp(640, 480, bits_per_pixel: 32)
      io = StringIO.new(bmp)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(32)
    end

    it 'detects 24-bit color depth for JPEG with 3 components' do
      jpeg = [
        0xFF, 0xD8,
        0xFF, 0xC0, 0x00, 0x0B, 0x08,
        0x01, 0x90, 0x00, 0xC8,
        0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01
      ].pack('C*')
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(24)
    end

    it 'detects 8-bit color depth for greyscale JPEG' do
      jpeg = [
        0xFF, 0xD8,
        0xFF, 0xC0,
        0x00, 0x08,
        0x08,
        0x00, 0x40, 0x00, 0x20,
        0x01,
        0x01, 0x11, 0x00
      ].pack('C*')
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.color_depth).to eq(8)
    end
  end

  describe 'ImageInfo#dpi' do
    it 'returns nil by default' do
      info = Philiprehberger::ImageSize::ImageInfo.new(width: 100, height: 100, format: :png)
      expect(info.dpi).to be_nil
    end

    it 'returns nil for JPEG without JFIF APP0' do
      jpeg = [
        0xFF, 0xD8,
        0xFF, 0xC0, 0x00, 0x0B, 0x08,
        0x01, 0x90, 0x00, 0xC8,
        0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01
      ].pack('C*')
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to be_nil
    end

    it 'extracts DPI from JPEG JFIF APP0 with dots per inch' do
      jpeg = build_jpeg_with_jfif(256, 512, x_density: 72, y_density: 72, units: 1)
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to eq({ x: 72.0, y: 72.0 })
    end

    it 'extracts DPI from JPEG JFIF APP0 with dots per centimeter' do
      jpeg = build_jpeg_with_jfif(256, 512, x_density: 28, y_density: 28, units: 2)
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to eq({ x: 71.12, y: 71.12 })
    end

    it 'returns nil for JPEG JFIF with no unit (aspect ratio only)' do
      jpeg = build_jpeg_with_jfif(256, 512, x_density: 1, y_density: 1, units: 0)
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to be_nil
    end

    it 'extracts DPI from PNG pHYs chunk' do
      png = build_png_with_phys(128, 64, ppu_x: 3780, ppu_y: 3780) # ~96 DPI
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to eq({ x: 96.01, y: 96.01 })
    end

    it 'returns nil for PNG without pHYs chunk' do
      png = build_png_ihdr(128, 64, bit_depth: 8, color_type: 2)
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to be_nil
    end

    it 'extracts DPI from BMP pixels per meter' do
      bmp = build_bmp(640, 480, bits_per_pixel: 24, ppm_x: 2835, ppm_y: 2835) # ~72 DPI
      io = StringIO.new(bmp)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to eq({ x: 72.01, y: 72.01 })
    end

    it 'returns nil for BMP without DPI' do
      bmp = build_bmp(640, 480, bits_per_pixel: 24, ppm_x: 0, ppm_y: 0)
      io = StringIO.new(bmp)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.dpi).to be_nil
    end
  end

  describe 'SVG viewBox edge cases' do
    it 'parses viewBox with floating-point dimensions' do
      svg = '<svg viewBox="0 0 100.5 200.7" xmlns="http://www.w3.org/2000/svg"></svg>'
      io = StringIO.new(svg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.width).to eq(100)
      expect(info.height).to eq(200)
      expect(info.format).to eq(:svg)
    end

    it 'parses viewBox with negative min-x and min-y' do
      svg = '<svg viewBox="-10 -20 500 400" xmlns="http://www.w3.org/2000/svg"></svg>'
      io = StringIO.new(svg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.width).to eq(500)
      expect(info.height).to eq(400)
    end

    it 'parses viewBox with mixed comma and space separators' do
      svg = '<svg viewBox="0, 0 300, 200" xmlns="http://www.w3.org/2000/svg"></svg>'
      io = StringIO.new(svg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.width).to eq(300)
      expect(info.height).to eq(200)
    end

    it 'falls back to viewBox when only width is present' do
      svg = '<svg width="100" viewBox="0 0 600 400" xmlns="http://www.w3.org/2000/svg"></svg>'
      io = StringIO.new(svg)
      info = Philiprehberger::ImageSize.of(io)
      # Falls back because height is missing
      expect(info.width).to eq(600)
      expect(info.height).to eq(400)
    end

    it 'returns nil for SVG without dimensions or viewBox' do
      svg = '<svg xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100"/></svg>'
      io = StringIO.new(svg)
      expect { Philiprehberger::ImageSize.of(io) }.to raise_error(Philiprehberger::ImageSize::Error)
    end
  end

  describe 'ImageInfo#interlaced?' do
    it 'detects Adam7 interlaced PNG' do
      png = build_png_ihdr(128, 64, bit_depth: 8, color_type: 2, interlace: 1)
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.interlaced?).to be true
    end

    it 'reports non-interlaced PNG' do
      png = build_png_ihdr(128, 64, bit_depth: 8, color_type: 2, interlace: 0)
      io = StringIO.new(png)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.interlaced?).to be false
    end

    it 'detects progressive JPEG via SOF2 marker' do
      jpeg = [
        0xFF, 0xD8,
        0xFF, 0xC2,
        0x00, 0x0B, 0x08,
        0x01, 0x90, 0x00, 0xC8,
        0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01
      ].pack('C*')
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.interlaced?).to be true
    end

    it 'reports baseline JPEG as not interlaced' do
      jpeg = [
        0xFF, 0xD8,
        0xFF, 0xC0,
        0x00, 0x0B, 0x08,
        0x01, 0x90, 0x00, 0xC8,
        0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01
      ].pack('C*')
      io = StringIO.new(jpeg)
      info = Philiprehberger::ImageSize.of(io)
      expect(info.interlaced?).to be false
    end
  end

  # Helper methods for building test binary data

  def build_exif_with_orientation(orientation_value)
    exif = "Exif\x00\x00"
    # TIFF header (little-endian)
    tiff = 'II'
    tiff += [42].pack('v')                       # Magic
    tiff += [8].pack('V')                        # IFD offset
    # IFD with 1 entry
    tiff += [1].pack('v') # entry count
    # Orientation tag (0x0112 = 274)
    tiff += [0x0112].pack('v')                   # tag
    tiff += [3].pack('v')                        # type = SHORT
    tiff += [1].pack('V')                        # count
    tiff += [orientation_value].pack('v')        # value
    tiff += "\x00\x00"                           # padding
    exif + tiff
  end

  def build_animated_gif(width, height)
    gif = 'GIF89a'
    gif += [width, height].pack('vv')
    gif += [0x00, 0x00, 0x00].pack('C3') # packed, bg, aspect

    # Application Extension: NETSCAPE2.0
    gif += [0x21, 0xFF].pack('C2')               # Extension + Application label
    gif += [0x0B].pack('C')                      # Block size = 11
    gif += 'NETSCAPE2.0'                         # Application identifier
    gif += [0x03].pack('C')                      # Sub-block size
    gif += [0x01].pack('C')                      # Sub-block ID
    gif += [0x00, 0x00].pack('C2')               # Loop count
    gif += [0x00].pack('C')                      # Block terminator

    # Image descriptor
    gif += [0x2C].pack('C')
    gif += "\x00" * 20

    gif
  end

  def build_gif_with_transparency(width, height)
    gif = 'GIF89a'
    gif += [width, height].pack('vv')
    gif += [0x00, 0x00, 0x00].pack('C3')

    # Graphics Control Extension with transparency
    gif += [0x21, 0xF9].pack('C2')               # Extension + GCE label
    gif += [0x04].pack('C')                      # Block size = 4
    gif += [0x01].pack('C')                      # Packed: transparent flag = 1
    gif += [0x00, 0x00].pack('C2')               # Delay time
    gif += [0x00].pack('C')                      # Transparent color index
    gif += [0x00].pack('C')                      # Block terminator

    # Image descriptor
    gif += [0x2C].pack('C')
    gif += "\x00" * 20

    gif
  end

  def build_avif(width, height, brand: 'avif')
    # ftyp box
    ftyp_data = brand                            # Major brand
    ftyp_data += [0].pack('N')                   # Minor version
    ftyp_data += 'avif'                          # Compatible brand
    ftyp_size = 8 + ftyp_data.length
    ftyp = "#{[ftyp_size].pack('N')}ftyp#{ftyp_data}"

    # Build a minimal meta box containing ispe
    # ispe box: 4-byte size + "ispe" + 4-byte version/flags + 4-byte width + 4-byte height
    ispe = "#{[20].pack('N')}ispe"
    ispe += [0].pack('N') # version + flags
    ispe += [width].pack('N')
    ispe += [height].pack('N')

    # iprp box containing ipco containing ispe
    ipco = "#{[8 + ispe.length].pack('N')}ipco#{ispe}"
    iprp = "#{[8 + ipco.length].pack('N')}iprp#{ipco}"

    # meta box (fullbox: version + flags = 4 bytes)
    meta_content = [0].pack('N') + iprp # version/flags + iprp
    meta = "#{[8 + meta_content.length].pack('N')}meta#{meta_content}"

    ftyp + meta
  end

  def build_png_ihdr(width, height, bit_depth: 8, color_type: 2, interlace: 0)
    png = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, # PNG signature
      0x00, 0x00, 0x00, 0x0D # IHDR chunk length (13)
    ].pack('C*')
    png += 'IHDR'
    png += [width].pack('N')
    png += [height].pack('N')
    png += [bit_depth, color_type, 0, 0, interlace].pack('C5') # bit depth, color type, compression, filter, interlace
    png += [0].pack('N') # CRC placeholder
    # Add IDAT chunk to stop scanning
    png += "#{[0].pack('N')}IDAT#{[0].pack('N')}"
    png
  end

  def build_png_with_phys(width, height, ppu_x:, ppu_y:, bit_depth: 8, color_type: 2)
    png = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D
    ].pack('C*')
    png += 'IHDR'
    png += [width].pack('N')
    png += [height].pack('N')
    png += [bit_depth, color_type, 0, 0, 0].pack('C5')
    png += [0].pack('N') # CRC

    # pHYs chunk: 9 bytes data (4 X ppu + 4 Y ppu + 1 unit)
    phys_data = [ppu_x].pack('N') + [ppu_y].pack('N') + [1].pack('C') # unit=1 (meter)
    png += [9].pack('N') # chunk length
    png += 'pHYs'
    png += phys_data
    png += [0].pack('N') # CRC

    # IDAT to stop scanning
    png += "#{[0].pack('N')}IDAT#{[0].pack('N')}"
    png
  end

  def build_jpeg_with_jfif(width, height, x_density:, y_density:, units:)
    # JFIF APP0 data
    jfif = "JFIF\x00"          # identifier
    jfif += [1, 1].pack('CC')  # version 1.1
    jfif += [units].pack('C')  # units
    jfif += [x_density].pack('n')
    jfif += [y_density].pack('n')
    jfif += [0, 0].pack('CC')  # thumbnail dimensions

    app0_length = jfif.length + 2

    jpeg = [0xFF, 0xD8].pack('C*')       # SOI
    jpeg += [0xFF, 0xE0].pack('C*')      # APP0 marker
    jpeg += [app0_length].pack('n')      # APP0 length
    jpeg += jfif
    jpeg += [0xFF, 0xC0].pack('C*')      # SOF0
    jpeg += [0x00, 0x0B].pack('C*')      # length
    jpeg += [0x08].pack('C')             # precision
    jpeg += [height].pack('n')
    jpeg += [width].pack('n')
    jpeg += [0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01].pack('C*')
    jpeg
  end

  def build_bmp(width, height, bits_per_pixel: 24, ppm_x: 0, ppm_y: 0)
    bmp = 'BM'
    bmp += [0].pack('V')          # file size (not important for detection)
    bmp += [0].pack('V')          # reserved
    bmp += [54].pack('V')         # data offset
    bmp += [40].pack('V')         # DIB header size
    bmp += [width].pack('V')
    bmp += [height].pack('l<')
    bmp += [1].pack('v')          # planes
    bmp += [bits_per_pixel].pack('v')
    bmp += [0].pack('V')          # compression
    bmp += [0].pack('V')          # image size
    bmp += [ppm_x].pack('V')     # X pixels per meter
    bmp += [ppm_y].pack('V')     # Y pixels per meter
    bmp += [0].pack('V')          # colors used
    bmp += [0].pack('V')          # important colors
    bmp
  end
end
