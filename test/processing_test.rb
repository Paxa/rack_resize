require_relative 'test_helper'
require 'rszr'
require 'mini_magick'

# MiniMagick.logger.level = :debug

describe RackResize::Processing do
  SAMPLES_DIR  = Pathname.new(File.expand_path('../samples', __dir__))
  SAMPLE_JPEG  = SAMPLES_DIR.join('image_1.jpeg') # 300x400
  SAMPLE_PNG   = SAMPLES_DIR.join('sample.png')   # 96x104
  SAMPLE_HEIC  = SAMPLES_DIR.join('sample.heic')  # 300x400
  SAMPLE_SVG   = SAMPLES_DIR.join('sample.svg')   # 104x97
  SAMPLE_WEBP  = SAMPLES_DIR.join('sample.webp')  # 550x368
  SAMPLE_AVIF  = SAMPLES_DIR.join('sample.avif')  # 900x1200

  IMAGE_MAGIC_DETECTED      = system('magick -version > /dev/null 2>&1') || system('convert -version > /dev/null 2>&1') || false
  IMAGE_MAGIC_HEIC_DETECTED = system("convert samples/sample1.heic /dev/null")
  IMAGE_MAGIC_AVIF_DETECTED = IMAGE_MAGIC_DETECTED && system("magick identify samples/sample.avif > /dev/null 2>&1")
  VIPS_HEIC_DETECTED        = system("vips thumbnail samples/sample.heic /tmp/sample_heic_check.heic 10 > /dev/null 2>&1")
  VIPS_AVIF_DETECTED        = system("vips thumbnail samples/sample.avif /tmp/sample_avif_check.avif 10 > /dev/null 2>&1")

  before { @tmpdir = Dir.mktmpdir('rack_resize_processing_test') }
  after  { FileUtils.rm_rf(@tmpdir) }

  it 'returns a StringIO' do
    assert_kind_of StringIO,
      processing(:imlib2).process!(source_file: SAMPLE_JPEG, req_params: {})
  end

  describe 'req_params' do
    it 'supports w shorthand' do
      assert_dimensions processing(:imlib2)
        .process!(source_file: SAMPLE_JPEG, req_params: {w: '150'}), 150, 200
    end

    it 'supports h shorthand' do
      assert_dimensions processing(:imlib2)
        .process!(source_file: SAMPLE_JPEG, req_params: {h: '200'}), 150, 200
    end

    it 'multiplies dimensions by dpr' do
      assert_dimensions processing(:imlib2)
        .process!(source_file: SAMPLE_JPEG, req_params: {width: '75', dpr: '2'}), 150, 200
    end

    it 'clamps width to max_dimension' do
      config = make_config(:imlib2, max_dimension: 100)
      io = RackResize::Processing.new(config: config)
               .process!(source_file: SAMPLE_JPEG, req_params: {width: '99999'})
      w, = read_dimensions_from(io)
      assert_operator w, :<=, 100
    end

    it 'clamps height to max_dimension' do
      config = make_config(:imlib2, max_dimension: 100)
      io = RackResize::Processing.new(config: config)
               .process!(source_file: SAMPLE_JPEG, req_params: {height: '99999'})
      _, h = read_dimensions_from(io)
      assert_operator h, :<=, 100
    end

    it 'clamps dpr to avoid multiplication overflow' do
      config = make_config(:imlib2, max_dimension: 200)
      io = RackResize::Processing.new(config: config)
               .process!(source_file: SAMPLE_JPEG, req_params: {width: '10', dpr: '99999'})
      w, = read_dimensions_from(io)
      assert_operator w, :<=, 200
    end
  end

  describe 'save_resized: true' do
    it 'caches the result and reuses it on subsequent calls' do
      cache  = Pathname.new(File.join(@tmpdir, 'cache'))
      config = make_config(:imlib2, save_resized: true, cache_folder: cache)
      r1 = RackResize::Processing.new(config: config)
               .process!(source_file: SAMPLE_JPEG, req_params: {width: '150'})
      r2 = RackResize::Processing.new(config: config)
               .process!(source_file: SAMPLE_JPEG, req_params: {width: '150'})
      assert_equal r2.read, r1.read
      assert_equal 1, cache.glob('**/*').count(&:file?)
    end
  end

  # -------------------------------------------------------------------------
  describe 'JPEG' do
    describe 'sips' do
      it 'resizes by width' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150'}), 150, 200
        end
      end

      it 'resizes by height' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {height: '200'}), 150, 200
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200
        end
      end

      it 'preserves original dimensions with no params' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {}), 300, 400
        end
      end
    end

    describe 'mini_magick' do
      it 'resizes by width' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150'}), 150, 200
        end
      end

      it 'resizes by height' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {height: '200'}), 150, 200
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200
        end
      end

      it 'preserves original dimensions with no params' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {}), 300, 400
        end
      end
    end

    describe 'vips' do
      it 'resizes by width' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150'}), 150, 200
        end
      end

      it 'resizes by height' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {height: '200'}), 150, 200
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200
        end
      end

      it 'preserves original dimensions with no params' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {}), 300, 400
        end
      end
    end

    describe 'imlib2' do
      it 'resizes by width' do
        with_processor(:imlib2) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150'}), 150, 200
        end
      end

      it 'resizes by height' do
        with_processor(:imlib2) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {height: '200'}), 150, 200
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:imlib2) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:imlib2) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200
        end
      end

      it 'preserves original dimensions with no params' do
        with_processor(:imlib2) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_JPEG, req_params: {}), 300, 400
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'PNG' do
    describe 'sips' do
      it 'resizes by width' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {width: '48'}), 48, 52, ext: '.png'
        end
      end

      it 'resizes by height' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {height: '52'}), 48, 52, ext: '.png'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '48', height: '104'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '96', height: '52'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end
    end

    describe 'mini_magick' do
      it 'resizes by width' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {width: '48'}), 48, 52, ext: '.png'
        end
      end

      it 'resizes by height' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {height: '52'}), 48, 52, ext: '.png'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '48', height: '104'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '96', height: '52'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end
    end

    describe 'vips' do
      it 'resizes by width' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {width: '48'}), 48, 52, ext: '.png'
        end
      end

      it 'resizes by height' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {height: '52'}), 48, 52, ext: '.png'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '48', height: '104'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '96', height: '52'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end
    end

    describe 'imlib2' do
      it 'resizes by width' do
        with_processor(:imlib2) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {width: '48'}), 48, 52, ext: '.png'
        end
      end

      it 'resizes by height' do
        with_processor(:imlib2) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_PNG, req_params: {height: '52'}), 48, 52, ext: '.png'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:imlib2) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '48', height: '104'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:imlib2) do |p|
          io = p.process!(source_file: SAMPLE_PNG, req_params: {width: '96', height: '52'})
          assert_dimensions io, 48, 52, ext: '.png'
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'HEIC' do
    describe 'sips' do
      it 'resizes by width' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150'}), 150, 200, ext: '.heic'
        end
      end

      it 'resizes by height' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {height: '200'}), 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end
    end

    describe 'mini_magick' do
      it 'resizes by width' do
        skip "ImageMagick without HEIC support" unless IMAGE_MAGIC_HEIC_DETECTED
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150'}), 150, 200, ext: '.heic'
        end
      end

      it 'resizes by height' do
        skip "ImageMagick without HEIC support" unless IMAGE_MAGIC_HEIC_DETECTED
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {height: '200'}), 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when width constrains' do
        skip "ImageMagick without HEIC support" unless IMAGE_MAGIC_HEIC_DETECTED
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when height constrains' do
        skip "ImageMagick without HEIC support" unless IMAGE_MAGIC_HEIC_DETECTED
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end
    end

    describe 'vips' do
      it 'resizes by width' do
        skip "Vips without HEIC support" unless VIPS_HEIC_DETECTED
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150'}), 150, 200, ext: '.heic'
        end
      end

      it 'resizes by height' do
        skip "Vips without HEIC support"  unless VIPS_HEIC_DETECTED
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {height: '200'}), 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when width constrains' do
        skip "Vips without HEIC support"  unless VIPS_HEIC_DETECTED
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when height constrains' do
        skip "Vips without HEIC support"  unless VIPS_HEIC_DETECTED
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'SVG' do
    describe 'mini_magick' do
      it 'resizes by width' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_SVG, req_params: {width: '52'}), 52, 49, ext: '.svg'
        end
      end

      it 'resizes by height' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_SVG, req_params: {height: '48'}), 51, 48, ext: '.svg'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_SVG, req_params: {width: '52', height: '97'})
          assert_dimensions io, 52, 49, ext: '.svg'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_SVG, req_params: {width: '104', height: '48'})
          assert_dimensions io, 51, 48, ext: '.svg'
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'AVIF' do
    describe 'sips' do
      it 'resizes by width' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_AVIF, req_params: {width: '450'}), 450, 600, ext: '.avif'
        end
      end

      it 'resizes by height' do
        with_processor(:sips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_AVIF, req_params: {height: '600'}), 450, 600, ext: '.avif'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_AVIF, req_params: {width: '450', height: '1200'})
          assert_dimensions io, 450, 600, ext: '.avif'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_AVIF, req_params: {width: '900', height: '600'})
          assert_dimensions io, 450, 600, ext: '.avif'
        end
      end
    end

    describe 'mini_magick' do
      it 'resizes by width' do
        skip 'ImageMagick without AVIF support' unless IMAGE_MAGIC_AVIF_DETECTED
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_AVIF, req_params: {width: '450'}), 450, 600, ext: '.avif'
        end
      end

      it 'resizes by height' do
        skip 'ImageMagick without AVIF support' unless IMAGE_MAGIC_AVIF_DETECTED
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_AVIF, req_params: {height: '600'}), 450, 600, ext: '.avif'
        end
      end

      it 'fits within box when width constrains' do
        skip 'ImageMagick without AVIF support' unless IMAGE_MAGIC_AVIF_DETECTED
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_AVIF, req_params: {width: '450', height: '1200'})
          assert_dimensions io, 450, 600, ext: '.avif'
        end
      end

      it 'fits within box when height constrains' do
        skip 'ImageMagick without AVIF support' unless IMAGE_MAGIC_AVIF_DETECTED
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_AVIF, req_params: {width: '900', height: '600'})
          assert_dimensions io, 450, 600, ext: '.avif'
        end
      end
    end

    describe 'vips' do
      it 'resizes by width' do
        skip 'Vips without AVIF support' unless VIPS_AVIF_DETECTED
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_AVIF, req_params: {width: '450'}), 450, 600, ext: '.avif'
        end
      end

      it 'resizes by height' do
        skip 'Vips without AVIF support' unless VIPS_AVIF_DETECTED
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_AVIF, req_params: {height: '600'}), 450, 600, ext: '.avif'
        end
      end

      it 'fits within box when width constrains' do
        skip 'Vips without AVIF support' unless VIPS_AVIF_DETECTED
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_AVIF, req_params: {width: '450', height: '1200'})
          assert_dimensions io, 450, 600, ext: '.avif'
        end
      end

      it 'fits within box when height constrains' do
        skip 'Vips without AVIF support' unless VIPS_AVIF_DETECTED
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_AVIF, req_params: {width: '900', height: '600'})
          assert_dimensions io, 450, 600, ext: '.avif'
        end
      end
    end

    describe 'convert to avif' do
      it 'mini_magick: converts JPEG to AVIF' do
        skip 'ImageMagick without AVIF support' unless IMAGE_MAGIC_AVIF_DETECTED
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'avif'})
          assert_dimensions io, 150, 200, ext: '.avif'
        end
      end

      it 'vips: converts JPEG to AVIF' do
        skip 'Vips without AVIF support' unless VIPS_AVIF_DETECTED
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'avif'})
          assert_dimensions io, 150, 200, ext: '.avif'
        end
      end

      it 'sips: converts JPEG to AVIF' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'avif'})
          assert_dimensions io, 150, 200, ext: '.avif'
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'fit' do
    # SAMPLE_JPEG is 300x400

    describe 'cover / crop — fills exact dimensions by cropping' do
      it 'sips: fit=cover produces exact dimensions' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'cover'})
          assert_dimensions io, 200, 200
        end
      end

      it 'mini_magick: fit=cover produces exact dimensions' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'cover'})
          assert_dimensions io, 200, 200
        end
      end

      it 'vips: fit=cover produces exact dimensions' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'cover'})
          assert_dimensions io, 200, 200
        end
      end

      it 'imlib2: fit=cover produces exact dimensions' do
        with_processor(:imlib2) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'cover'})
          assert_dimensions io, 200, 200
        end
      end

      it 'mini_magick: fit=crop is an alias for cover' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'crop'})
          assert_dimensions io, 200, 200
        end
      end

      it 'mini_magick: cover with non-square target fills both dimensions' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '300', height: '100', fit: 'cover'})
          assert_dimensions io, 300, 100
        end
      end
    end

    describe 'contain / bounds — fits within box preserving aspect ratio' do
      it 'mini_magick: fit=contain behaves like default (resize_to_limit)' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'contain'})
          assert_dimensions io, 150, 200
        end
      end

      it 'mini_magick: fit=bounds is an alias for contain' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'bounds'})
          assert_dimensions io, 150, 200
        end
      end

      it 'sips: fit=contain fits within box' do
        with_processor(:sips) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'contain'})
          assert_dimensions io, 150, 200
        end
      end

      it 'imlib2: fit=contain fits within box' do
        with_processor(:imlib2) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '200', height: '200', fit: 'contain'})
          assert_dimensions io, 150, 200
        end
      end
    end

    describe 'cover with single dimension falls back to contain behavior' do
      it 'mini_magick: fit=cover with only width acts as width limit' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', fit: 'cover'})
          assert_dimensions io, 150, 200
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'format conversion' do
    it 'mini_magick: converts JPEG to PNG' do
      with_processor(:mini_magick) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'png'})
        assert_dimensions io, 150, 200, ext: '.png'
      end
    end

    it 'mini_magick: converts JPEG to WebP' do
      with_processor(:mini_magick) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'webp'})
        assert_dimensions io, 150, 200, ext: '.webp'
      end
    end

    it 'vips: converts JPEG to WebP' do
      with_processor(:vips) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'webp'})
        assert_dimensions io, 150, 200, ext: '.webp'
      end
    end

    it 'imlib2: converts JPEG to PNG' do
      with_processor(:imlib2) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'png'})
        assert_dimensions io, 150, 200, ext: '.png'
      end
    end

    it 'imlib2: converts JPEG to WebP' do
      with_processor(:imlib2) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'webp'})
        assert_dimensions io, 150, 200, ext: '.webp'
      end
    end

    it 'sips: converts JPEG to PNG' do
      with_processor(:sips) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'png'})
        assert_dimensions io, 150, 200, ext: '.png'
      end
    end

    it "format=auto is treated as no conversion (uses source format)" do
      with_processor(:mini_magick) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', format: 'auto'})
        assert_dimensions io, 150, 200
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'quality' do
    it 'mini_magick: per-request quality overrides default' do
      with_processor(:mini_magick) do |p|
        hi = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', quality: '95'})
        lo = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', quality: '10'})
        assert_operator lo.size, :<, hi.size
      end
    end

    it 'vips: per-request quality overrides default' do
      with_processor(:vips) do |p|
        hi = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', quality: '95'})
        lo = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', quality: '10'})
        assert_operator lo.size, :<, hi.size
      end
    end

    it 'sips: accepts quality param without error' do
      with_processor(:sips) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', quality: '50'})
        assert_kind_of StringIO, io
      end
    end

    it 'imlib2: accepts quality param without error' do
      with_processor(:imlib2) do |p|
        io = p.process!(source_file: SAMPLE_JPEG, req_params: {width: '150', quality: '50'})
        assert_kind_of StringIO, io
      end
    end
  end

  # -------------------------------------------------------------------------
  describe 'WebP' do
    describe 'mini_magick' do
      it 'resizes by width' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_WEBP, req_params: {width: '275'}), 275, 184, ext: '.webp'
        end
      end

      it 'resizes by height' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_WEBP, req_params: {height: '184'}), 275, 184, ext: '.webp'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_WEBP, req_params: {width: '275', height: '368'})
          assert_dimensions io, 275, 184, ext: '.webp'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_WEBP, req_params: {width: '550', height: '184'})
          assert_dimensions io, 275, 184, ext: '.webp'
        end
      end
    end

    describe 'vips' do
      it 'resizes by width' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_WEBP, req_params: {width: '275'}), 275, 184, ext: '.webp'
        end
      end

      it 'resizes by height' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_WEBP, req_params: {height: '184'}), 275, 184, ext: '.webp'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_WEBP, req_params: {width: '275', height: '368'})
          assert_dimensions io, 275, 184, ext: '.webp'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_WEBP, req_params: {width: '550', height: '184'})
          assert_dimensions io, 275, 184, ext: '.webp'
        end
      end
    end
  end

  private

  def make_config(processor, save_resized: false, cache_folder: nil, max_dimension: nil)
    opts = {processor: processor, save_resized: save_resized, cache_folder: cache_folder}
    opts[:max_dimension] = max_dimension if max_dimension
    RackResize::Configuration.new(**opts)
  end

  def processing(processor)
    RackResize::Processing.new(config: make_config(processor))
  end

  def with_processor(processor)
    check_available(processor)
    yield processing(processor)
  rescue => e
    raise unless e.message =~ /unsupported format|can't write format|format not supported/i
    skip "#{processor} doesn't support this format on this system: #{e.message.lines.first.strip}"
  end

  def check_available(processor)
    case processor
    when :sips
      skip 'sips is macOS-only' unless RUBY_PLATFORM.include?('darwin')
    when :mini_magick
      skip 'ImageMagick not found' unless IMAGE_MAGIC_DETECTED
    when :vips
      begin
        require 'vips'
      rescue LoadError
        skip 'ruby-vips / libvips not available'
      end
    end
  end

  def assert_dimensions(io, expected_w, expected_h, ext: '.jpg')
    io.rewind
    Tempfile.create(['dim_check', ext]) do |f|
      f.binmode
      f.write(io.read)
      f.flush
      f.close
      w, h = read_dimensions(f.path)
      assert_equal expected_w, w, 'width mismatch'
      assert_equal expected_h, h, 'height mismatch'
    end
  end

  def read_dimensions(path)
    img = Rszr::Image.load(path)
    [img.width, img.height]
  rescue Rszr::LoadError
    img = MiniMagick::Image.open(path)
    [img.width, img.height]
  end

  def read_dimensions_from(io, ext: '.jpg')
    io.rewind
    Tempfile.create(['dim_check', ext]) do |f|
      f.binmode; f.write(io.read); f.flush; f.close
      return read_dimensions(f.path)
    end
  end
end
