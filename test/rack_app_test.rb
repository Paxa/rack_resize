require_relative 'test_helper'
require 'logger'

UPSTREAM = ->(env) { [200, { 'content-type' => 'text/plain' }, ['upstream']] }

describe RackResize::RackApp do
  before do
    @tmpdir = Dir.mktmpdir('rack_resize_test')
    File.write(File.join(@tmpdir, 'photo.jpg'), 'fake jpeg content')

    @app = RackResize::RackApp.new(
      UPSTREAM,
      assets_folders: { "assets" => @tmpdir },
      processor:      :sips,
      save_resized:   false
    )

    fake_processing = Object.new
    def fake_processing.process!(**) = StringIO.new('processed image data')
    def fake_processing.logger = ::Logger.new(nil)
    @app.instance_variable_set(:@processing, fake_processing)
  end

  after do
    FileUtils.rm_rf(@tmpdir)
  end

  describe '#error_resp' do
    it 'returns 404 by default' do
      status, headers, body = @app.error_resp('oops')
      assert_equal 404, status
      assert_equal({}, headers)
      assert_equal ['oops'], body
    end

    it 'accepts a custom http_code' do
      status, _, body = @app.error_resp('bad input', http_code: 422)
      assert_equal 422, status
      assert_equal ['bad input'], body
    end
  end

  describe '#send_file' do
    it 'returns 200 with correct headers' do
      asset_file = Pathname.new(File.join(@tmpdir, 'photo.jpg'))
      status, headers, _ = @app.send_file(asset_file:, file_content: StringIO.new('hello'))
      assert_equal 200, status
      assert_equal 'image/jpeg', headers['content-type']
      assert_equal '5', headers['content-length']
      assert_equal 'inline', headers['content-disposition']
      assert_match(/\d+/, headers['cache-control'])
    end

    it 'uses output_format for content-type when specified' do
      asset_file = Pathname.new(File.join(@tmpdir, 'photo.jpg'))
      _, headers, _ = @app.send_file(asset_file:, file_content: StringIO.new('data'), output_format: 'webp')
      assert_equal 'image/webp', headers['content-type']
    end

    it 'falls back to source extension when output_format is nil' do
      asset_file = Pathname.new(File.join(@tmpdir, 'photo.jpg'))
      _, headers, _ = @app.send_file(asset_file:, file_content: StringIO.new('data'), output_format: nil)
      assert_equal 'image/jpeg', headers['content-type']
    end

    it 'ignores output_format=auto and uses source extension' do
      asset_file = Pathname.new(File.join(@tmpdir, 'photo.jpg'))
      _, headers, _ = @app.send_file(asset_file:, file_content: StringIO.new('data'), output_format: 'auto')
      assert_equal 'image/jpeg', headers['content-type']
    end
  end

  describe '#call' do
    describe 'pass-through' do
      it 'forwards unrelated paths to upstream' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/foo/bar.jpg'))
        assert_equal 200, status
        assert_equal ['upstream'], body
      end

      it 'forwards root path to upstream' do
        _, _, body = @app.call(Rack::MockRequest.env_for('/'))
        assert_equal ['upstream'], body
      end
    end

    describe 'path errors' do
      it 'returns 404 for unparseable path' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/bad-path-no-extension'))
        assert_equal 404, status
        assert_equal ["can't parse file path"], body
      end

      it 'returns 404 for path traversal' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/../etc/photo.jpg'))
        assert_equal 404, status
        assert_equal ['.. is not allowed in image path'], body
      end

      it 'returns 404 for missing file' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/missing.jpg'))
        assert_equal 404, status
        assert_equal ['file not exists on a server'], body
      end
    end

    describe 'successful processing' do
      it 'returns 200 with correct content-type' do
        status, headers, _ = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg'))
        assert_equal 200, status
        assert_equal 'image/jpeg', headers['content-type']
      end

      it 'handles multiple params' do
        status, = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=200,format=auto,quality=80/assets/photo.jpg'))
        assert_equal 200, status
      end

      it 'sets content-length from processed output' do
        _, headers, _ = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg'))
        assert_equal 'processed image data'.bytesize.to_s, headers['content-length']
      end

      it 'strips Rails asset digest fingerprint from filename' do
        status, _, _ = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo-1a2b3c4d.jpg'))
        assert_equal 200, status
      end
    end

    describe 'custom cf_path_prefix' do
      it 'does not intercept the default prefix when a custom one is set' do
        app = RackResize::RackApp.new(UPSTREAM, assets_folder: @tmpdir, processor: :sips,
                                                save_resized: false, cf_path_prefix: '/img')
        _, _, body = app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg'))
        assert_equal ['upstream'], body
      end
    end
  end

  it 'initializes without an upstream app' do
    app = RackResize::RackApp.new(assets_folder: @tmpdir, processor: :sips, save_resized: false)
    assert_nil app.instance_variable_get(:@app)
  end
end
