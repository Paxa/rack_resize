require_relative '../test_helper'

describe RackResize::InputParsers::QueryString do
  subject { RackResize::InputParsers::QueryString }

  describe 'no resize params present' do
    it 'returns route_matched: false for empty query string' do
      result = subject.parse_input('/assets/photo.jpg', '')
      assert_equal false, result[:route_matched]
      assert_nil result[:req_params]
      assert_nil result[:asset_path]
    end

    it 'returns route_matched: false for unrelated query params' do
      result = subject.parse_input('/assets/photo.jpg', 'foo=bar&baz=qux')
      assert_equal false, result[:route_matched]
    end

    it 'returns route_matched: false for nil query string' do
      result = subject.parse_input('/assets/photo.jpg', nil)
      assert_equal false, result[:route_matched]
    end
  end

  describe 'Fastly / bunny.net format (query string params)' do
    it 'parses width and height' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&height=100')
      assert_equal true, result[:route_matched]
      assert_equal({ width: '200', height: '100' }, result[:req_params])
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'parses short-form w and h' do
      result = subject.parse_input('/assets/photo.jpg', 'w=300&h=150')
      assert_equal true, result[:route_matched]
      assert_equal({ height: "150", width: "300" }, result[:req_params])
    end

    it 'parses quality param' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&quality=85')
      assert_equal({ width: '200', quality: '85' }, result[:req_params])
    end

    it 'parses dpr param' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&dpr=2')
      assert_equal({ width: '200', dpr: '2' }, result[:req_params])
    end

    it 'parses format param' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&format=webp')
      assert_equal({ width: '200', format: 'webp' }, result[:req_params])
    end

    it 'parses f shortcut as format' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&f=webp')
      assert_equal({ width: '200', format: 'webp' }, result[:req_params])
    end

    it 'parses q shortcut as quality' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&q=80')
      assert_equal({ width: '200', quality: '80' }, result[:req_params])
    end

    it 'f alone triggers route_matched' do
      result = subject.parse_input('/assets/photo.jpg', 'f=webp')
      assert_equal true, result[:route_matched]
      assert_equal({ format: 'webp' }, result[:req_params])
    end

    it 'q alone triggers route_matched' do
      result = subject.parse_input('/assets/photo.jpg', 'q=85')
      assert_equal true, result[:route_matched]
      assert_equal({ quality: '85' }, result[:req_params])
    end

    it 'parses fit param' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&height=200&fit=cover')
      assert_equal({ width: '200', height: '200', fit: 'cover' }, result[:req_params])
    end

    it 'fit alone triggers route_matched' do
      result = subject.parse_input('/assets/photo.jpg', 'fit=cover')
      assert_equal true, result[:route_matched]
      assert_equal({ fit: 'cover' }, result[:req_params])
    end

    it 'parses all params together including shortcuts' do
      result = subject.parse_input('/assets/photo.jpg', 'w=200&h=200&f=webp&q=80&fit=cover&dpr=2')
      assert_equal({ width: '200', height: '200', format: 'webp', quality: '80', fit: 'cover', dpr: '2' }, result[:req_params])
    end

    it 'explicit format takes precedence over f shortcut when both present' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&f=png&format=webp')
      assert_equal 'webp', result[:req_params][:format]
    end

    it 'matches with only width present' do
      result = subject.parse_input('/assets/photo.jpg', 'width=400')
      assert_equal true, result[:route_matched]
    end

    it 'matches with only height present' do
      result = subject.parse_input('/assets/photo.jpg', 'height=300')
      assert_equal true, result[:route_matched]
    end

    it 'ignores unrecognized query params' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200&crop=center&unknown=abc')
      assert_equal({ width: '200' }, result[:req_params])
    end

    it 'strips Rails asset digest fingerprint from path' do
      result = subject.parse_input('/assets/photo-1a2b3c4d.jpg', 'width=200')
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'strips 8-char hex fingerprint' do
      result = subject.parse_input('/assets/logo-deadbeef.png', 'width=100')
      assert_equal '/assets/logo.png', result[:asset_path]
    end

    it 'preserves path without fingerprint unchanged' do
      result = subject.parse_input('/assets/photo.jpg', 'width=200')
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'handles full set of params together' do
      result = subject.parse_input('/assets/photo.jpg', 'width=800&height=600&quality=90&dpr=2&format=webp')
      assert_equal true, result[:route_matched]
      assert_equal({ width: '800', height: '600', quality: '90', dpr: '2', format: 'webp' }, result[:req_params])
    end
  end

  describe 'pass-through in RackApp' do
    before do
      @tmpdir = Dir.mktmpdir('rack_resize_qs_test')
      File.write(File.join(@tmpdir, 'photo.jpg'), 'fake jpeg content')

      @app = RackResize::RackApp.new(
        ->(env) { [200, {}, ['upstream']] },
        assets_folders: { 'assets' => @tmpdir },
        processor: :sips,
        save_resized: false
      )

      fake_processing = Object.new
      def fake_processing.process!(**) = StringIO.new('processed')
      def fake_processing.logger = ::Logger.new(nil)
      @app.instance_variable_set(:@processing, fake_processing)
    end

    after { FileUtils.rm_rf(@tmpdir) }

    it 'passes through when no resize params in query string' do
      _, _, body = @app.call(Rack::MockRequest.env_for('/assets/photo.jpg?foo=bar'))
      assert_equal ['upstream'], body
    end

    it 'passes through when query string is empty' do
      _, _, body = @app.call(Rack::MockRequest.env_for('/assets/photo.jpg'))
      assert_equal ['upstream'], body
    end

    it 'processes image when width param is present' do
      status, headers, _ = @app.call(Rack::MockRequest.env_for('/assets/photo.jpg?width=200'))
      assert_equal 200, status
      assert_equal 'image/jpeg', headers['content-type']
    end

    it 'processes image with bunny.net style params' do
      status, _, _ = @app.call(Rack::MockRequest.env_for('/assets/photo.jpg?width=300&height=200&quality=85'))
      assert_equal 200, status
    end

    it 'processes image with Fastly style params' do
      status, _, _ = @app.call(Rack::MockRequest.env_for('/assets/photo.jpg?width=400&format=webp&dpr=2'))
      assert_equal 200, status
    end

    it 'cloudflare format still takes priority over query string' do
      status, _, body = @app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg?width=200'))
      assert_equal 200, status
      refute_equal ['upstream'], body
    end
  end
end
