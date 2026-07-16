require_relative 'test_helper'
require 'rszr'
require 'mini_magick'

describe RackResize::Processing do
  SAMPLES_DIR  = Pathname.new(File.expand_path('../samples', __dir__))
  SAMPLE_JPEG  = SAMPLES_DIR.join('image_1.jpeg') # 300x400
  SAMPLE_PNG   = SAMPLES_DIR.join('sample.png')   # 96x104
  SAMPLE_HEIC  = SAMPLES_DIR.join('sample.heic')  # 300x400
  SAMPLE_SVG   = SAMPLES_DIR.join('sample.svg')   # 104x97
  SAMPLE_WEBP  = SAMPLES_DIR.join('sample.webp')  # 550x368

  before { @tmpdir = Dir.mktmpdir('rack_resize_processing_test') }
  after  { FileUtils.rm_rf(@tmpdir) }

  it 'returns a StringIO' do
    _(processing(:imlib2).process!(source_file: SAMPLE_JPEG, req_params: {}))
      .must_be_kind_of StringIO
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
      _(w).must_be :<=, 100
    end

    it 'clamps height to max_dimension' do
      config = make_config(:imlib2, max_dimension: 100)
      io = RackResize::Processing.new(config: config)
               .process!(source_file: SAMPLE_JPEG, req_params: {height: '99999'})
      _, h = read_dimensions_from(io)
      _(h).must_be :<=, 100
    end

    it 'clamps dpr to avoid multiplication overflow' do
      config = make_config(:imlib2, max_dimension: 200)
      io = RackResize::Processing.new(config: config)
               .process!(source_file: SAMPLE_JPEG, req_params: {width: '10', dpr: '99999'})
      w, = read_dimensions_from(io)
      _(w).must_be :<=, 200
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
      _(r1.read).must_equal r2.read
      _(cache.glob('**/*').count(&:file?)).must_equal 1
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
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150'}), 150, 200, ext: '.heic'
        end
      end

      it 'resizes by height' do
        with_processor(:mini_magick) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {height: '200'}), 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when height constrains' do
        with_processor(:mini_magick) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '300', height: '200'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end
    end

    describe 'vips' do
      it 'resizes by width' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150'}), 150, 200, ext: '.heic'
        end
      end

      it 'resizes by height' do
        with_processor(:vips) do |p|
          assert_dimensions p.process!(source_file: SAMPLE_HEIC, req_params: {height: '200'}), 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when width constrains' do
        with_processor(:vips) do |p|
          io = p.process!(source_file: SAMPLE_HEIC, req_params: {width: '150', height: '400'})
          assert_dimensions io, 150, 200, ext: '.heic'
        end
      end

      it 'fits within box when height constrains' do
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
      skip 'ImageMagick not found' unless system('magick -version > /dev/null 2>&1') ||
                                          system('convert -version > /dev/null 2>&1')
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
      _(w).must_equal expected_w, 'width mismatch'
      _(h).must_equal expected_h, 'height mismatch'
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
