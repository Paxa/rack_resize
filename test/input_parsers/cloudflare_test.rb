require_relative '../test_helper'

describe RackResize::InputParsers::Cloudflare do
  subject { RackResize::InputParsers::Cloudflare }
  let(:prefix) { '/cdn-cgi/image' }

  describe 'path does not match prefix' do
    it 'returns route_matched: false for unrelated path' do
      result = subject.parse_input('/assets/photo.jpg', cf_path_prefix: prefix)
      assert_equal false, result[:route_matched]
      assert_nil result[:req_params]
      assert_nil result[:asset_path]
    end

    it 'returns route_matched: false for root path' do
      result = subject.parse_input('/', cf_path_prefix: prefix)
      assert_equal false, result[:route_matched]
    end

    it 'returns route_matched: false for empty path' do
      result = subject.parse_input('', cf_path_prefix: prefix)
      assert_equal false, result[:route_matched]
    end

    it 'returns route_matched: false when prefix is custom and path uses default' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/photo.jpg', cf_path_prefix: '/img')
      assert_equal false, result[:route_matched]
    end
  end

  describe 'path matches prefix but is unparseable' do
    it 'returns route_matched: true with nil params and path when no extension' do
      result = subject.parse_input('/cdn-cgi/image/bad-path-no-extension', cf_path_prefix: prefix)
      assert_equal true, result[:route_matched]
      assert_nil result[:req_params]
      assert_nil result[:asset_path]
    end

    it 'returns route_matched: true with nils when params segment is missing' do
      result = subject.parse_input('/cdn-cgi/image/', cf_path_prefix: prefix)
      assert_equal true, result[:route_matched]
      assert_nil result[:req_params]
    end
  end

  describe 'successful parse' do
    it 'parses width param' do
      result = subject.parse_input('/cdn-cgi/image/width=426/assets/photo.jpg', cf_path_prefix: prefix)
      assert_equal true, result[:route_matched]
      assert_equal({ width: '426' }, result[:req_params])
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'parses multiple comma-separated params' do
      result = subject.parse_input('/cdn-cgi/image/width=426,format=auto/assets/photo.jpg', cf_path_prefix: prefix)
      assert_equal({ width: '426', format: 'auto' }, result[:req_params])
    end

    it 'parses all common params' do
      result = subject.parse_input('/cdn-cgi/image/width=800,height=600,quality=85,dpr=2,format=webp/assets/photo.jpg', cf_path_prefix: prefix)
      assert_equal({ width: '800', height: '600', quality: '85', dpr: '2', format: 'webp' }, result[:req_params])
    end

    it 'uses symbolized keys' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/photo.jpg', cf_path_prefix: prefix)
      assert result[:req_params].key?(:width)
    end

    it 'extracts asset path with leading slash' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/templates/banner.jpg', cf_path_prefix: prefix)
      assert_equal '/assets/templates/banner.jpg', result[:asset_path]
    end

    it 'preserves nested asset path' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/a/b/c/photo.jpg', cf_path_prefix: prefix)
      assert_equal '/assets/a/b/c/photo.jpg', result[:asset_path]
    end

    it 'strips Rails asset digest fingerprint' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/photo-1a2b3c4d.jpg', cf_path_prefix: prefix)
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'strips 8-char hex fingerprint' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/logo-deadbeef.png', cf_path_prefix: prefix)
      assert_equal '/assets/logo.png', result[:asset_path]
    end

    it 'does not strip a non-fingerprint suffix' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/photo-v2.jpg', cf_path_prefix: prefix)
      assert_equal '/assets/photo-v2.jpg', result[:asset_path]
    end

    it 'handles png extension' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/logo.png', cf_path_prefix: prefix)
      assert_equal '/assets/logo.png', result[:asset_path]
    end

    it 'handles webp extension' do
      result = subject.parse_input('/cdn-cgi/image/width=100/assets/image.webp', cf_path_prefix: prefix)
      assert_equal '/assets/image.webp', result[:asset_path]
    end
  end

  describe 'custom cf_path_prefix' do
    it 'matches when path starts with custom prefix' do
      result = subject.parse_input('/img/width=200/assets/photo.jpg', cf_path_prefix: '/img')
      assert_equal true, result[:route_matched]
    end

    it 'parses params with custom prefix' do
      result = subject.parse_input('/img/width=200,height=100/assets/photo.jpg', cf_path_prefix: '/img')
      assert_equal({ width: '200', height: '100' }, result[:req_params])
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end
  end
end
