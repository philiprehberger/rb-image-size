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
        # Minimal valid PNG: 8-byte signature + IHDR chunk (13 bytes data)
        # IHDR: 4-byte length (13) + "IHDR" + 4-byte width + 4-byte height + 5 bytes (depth, color, etc.)
        png = [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, # PNG signature
          0x00, 0x00, 0x00, 0x0D,                           # IHDR chunk length (13)
          0x49, 0x48, 0x44, 0x52,                           # "IHDR"
          0x00, 0x00, 0x00, 0x80,                           # width = 128
          0x00, 0x00, 0x00, 0x40,                           # height = 64
          0x08, 0x02, 0x00, 0x00, 0x00                      # bit depth, color type, compression, filter, interlace
        ].pack('C*')

        io = StringIO.new(png)
        info = described_class.of(io)

        expect(info.width).to eq(128)
        expect(info.height).to eq(64)
        expect(info.format).to eq(:png)
      end
    end

    context 'with JPEG' do
      it 'detects dimensions and format from a minimal JPEG with SOF0' do
        # Minimal JPEG: SOI + APP0 marker (short) + SOF0 marker with dimensions
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
          0xFF, 0xD8,                         # SOI
          0xFF, 0xC2,                         # SOF2 marker (progressive)
          0x00, 0x0B,                         # length
          0x08,                               # precision
          0x01, 0x90,                         # height = 400
          0x00, 0xC8,                         # width = 200
          0x03,                               # components
          0x01, 0x11, 0x00,
          0x02, 0x11, 0x01
        ].pack('C*')

        io = StringIO.new(jpeg)
        info = described_class.of(io)

        expect(info.width).to eq(200)
        expect(info.height).to eq(400)
        expect(info.format).to eq(:jpeg)
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
    end

    context 'with BMP' do
      it 'detects dimensions from a BMP header' do
        # BMP: "BM" + file size (4) + reserved (4) + offset (4) + header size (4) + width (4) + height (4)
        bmp = 'BM'
        bmp += [0].pack('V')          # file size (placeholder)
        bmp += [0].pack('V')          # reserved
        bmp += [54].pack('V')         # pixel data offset
        bmp += [40].pack('V')         # DIB header size (BITMAPINFOHEADER)
        bmp += [640].pack('V')        # width
        bmp += [480].pack('l<')       # height (signed, positive = bottom-up)

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
        bmp += [-600].pack('l<')      # negative height = top-down

        io = StringIO.new(bmp)
        info = described_class.of(io)

        expect(info.width).to eq(800)
        expect(info.height).to eq(600)
        expect(info.format).to eq(:bmp)
      end
    end

    context 'with WebP' do
      it 'detects dimensions from VP8 (lossy) WebP' do
        # RIFF header + WEBP + VP8 chunk
        webp = 'RIFF'
        webp += [100].pack('V')       # file size
        webp += 'WEBP'
        webp += 'VP8 '                # VP8 lossy chunk
        webp += [30].pack('V')        # chunk size
        # VP8 bitstream: 3-byte frame tag + 3-byte sync code (0x9D 0x01 0x2A) + width(16) + height(16)
        webp += [0x00, 0x00, 0x00].pack('C3')    # frame tag
        webp += [0x9D, 0x01, 0x2A].pack('C3')    # sync code
        webp += [320].pack('v')       # width (14 bits used, no scale)
        webp += [240].pack('v')       # height (14 bits used, no scale)
        webp += "\x00" * 10           # padding

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.width).to eq(320)
        expect(info.height).to eq(240)
        expect(info.format).to eq(:webp)
      end

      it 'detects dimensions from VP8L (lossless) WebP' do
        # RIFF header + WEBP + VP8L chunk
        webp = 'RIFF'
        webp += [100].pack('V')       # file size
        webp += 'WEBP'
        webp += 'VP8L'                # VP8L lossless chunk
        webp += [20].pack('V')        # chunk size
        webp += [0x2F].pack('C')      # VP8L signature byte

        # Pack width-1 (13 bits) and height-1 (13 bits) into 4 bytes LE
        # width=256 -> 255, height=128 -> 127
        # bits: (127 << 14) | 255
        bits = (127 << 14) | 255
        webp += [bits].pack('V')
        webp += "\x00" * 10

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.width).to eq(256)
        expect(info.height).to eq(128)
        expect(info.format).to eq(:webp)
      end

      it 'detects dimensions from VP8X (extended) WebP' do
        # RIFF header + WEBP + VP8X chunk
        webp = 'RIFF'
        webp += [100].pack('V')       # file size
        webp += 'WEBP'
        webp += 'VP8X'                # VP8X extended chunk
        webp += [10].pack('V')        # chunk size
        webp += [0x00, 0x00, 0x00, 0x00].pack('C4') # flags + reserved

        # Canvas width-1 as 24-bit LE, then height-1 as 24-bit LE
        w_raw = 1023   # width = 1024
        h_raw = 767    # height = 768
        webp += [w_raw & 0xFF, (w_raw >> 8) & 0xFF, (w_raw >> 16) & 0xFF].pack('C3')
        webp += [h_raw & 0xFF, (h_raw >> 8) & 0xFF, (h_raw >> 16) & 0xFF].pack('C3')

        io = StringIO.new(webp)
        info = described_class.of(io)

        expect(info.width).to eq(1024)
        expect(info.height).to eq(768)
        expect(info.format).to eq(:webp)
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
        0x00, 0x00, 0x01, 0x00, # width = 256
        0x00, 0x00, 0x00, 0xC8, # height = 200
        0x08, 0x02, 0x00, 0x00, 0x00
      ].pack('C*')

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
      it 'returns a hash with width, height, and format' do
        expect(info.to_h).to eq({ width: 800, height: 600, format: :png })
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
end
