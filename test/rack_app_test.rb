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
      _(status).must_equal 404
      _(headers).must_equal({})
      _(body).must_equal ['oops']
    end

    it 'accepts a custom http_code' do
      status, _, body = @app.error_resp('bad input', http_code: 422)
      _(status).must_equal 422
      _(body).must_equal ['bad input']
    end
  end

  describe '#send_file' do
    it 'returns 200 with correct headers' do
      asset_file = Pathname.new(File.join(@tmpdir, 'photo.jpg'))
      status, headers, _ = @app.send_file(asset_file:, file_content: StringIO.new('hello'))
      _(status).must_equal 200
      _(headers['content-type']).must_equal 'image/jpeg'
      _(headers['content-length']).must_equal '5'
      _(headers['content-disposition']).must_equal 'inline'
      _(headers['cache-control']).must_match(/\d+/)
    end
  end

  describe '#call' do
    describe 'pass-through' do
      it 'forwards unrelated paths to upstream' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/foo/bar.jpg'))
        _(status).must_equal 200
        _(body).must_equal ['upstream']
      end

      it 'forwards root path to upstream' do
        _, _, body = @app.call(Rack::MockRequest.env_for('/'))
        _(body).must_equal ['upstream']
      end
    end

    describe 'path errors' do
      it 'returns 404 for unparseable path' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/bad-path-no-extension'))
        _(status).must_equal 404
        _(body).must_equal ["can't parse file path"]
      end

      it 'returns 404 for path traversal' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/../etc/photo.jpg'))
        _(status).must_equal 404
        _(body).must_equal ['.. is not allowed in image path']
      end

      it 'returns 404 for missing file' do
        status, _, body = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/missing.jpg'))
        _(status).must_equal 404
        _(body).must_equal ['file not exists on a server']
      end
    end

    describe 'successful processing' do
      it 'returns 200 with correct content-type' do
        status, headers, _ = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg'))
        _(status).must_equal 200
        _(headers['content-type']).must_equal 'image/jpeg'
      end

      it 'handles multiple params' do
        status, = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=200,format=auto,quality=80/assets/photo.jpg'))
        _(status).must_equal 200
      end

      it 'sets content-length from processed output' do
        _, headers, _ = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg'))
        _(headers['content-length']).must_equal 'processed image data'.bytesize.to_s
      end

      it 'strips Rails asset digest fingerprint from filename' do
        status, _, _ = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo-1a2b3c4d.jpg'))
        _(status).must_equal 200
      end
    end

    describe 'custom cf_path_prefix' do
      it 'does not intercept the default prefix when a custom one is set' do
        app = RackResize::RackApp.new(UPSTREAM, assets_folder: @tmpdir, processor: :sips,
                                                save_resized: false, cf_path_prefix: '/img')
        _, _, body = app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg'))
        _(body).must_equal ['upstream']
      end
    end
  end

  it 'initializes without an upstream app' do
    app = RackResize::RackApp.new(assets_folder: @tmpdir, processor: :sips, save_resized: false)
    _(app.instance_variable_get(:@app)).must_be_nil
  end
end
