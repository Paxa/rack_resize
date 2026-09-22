require_relative '../test_helper'

describe RackResize::InputParsers::Imgproxy do
  subject { RackResize::InputParsers::Imgproxy }

  describe 'path does not match imgproxy format' do
    it 'returns route_matched: false for standard static file path' do
      result = subject.parse_input('/assets/photo.jpg')
      assert_equal false, result[:route_matched]
      assert_nil result[:req_params]
      assert_nil result[:asset_path]
    end

    it 'returns route_matched: false for root path' do
      result = subject.parse_input('/')
      assert_equal false, result[:route_matched]
    end

    it 'returns route_matched: false for empty path' do
      result = subject.parse_input('')
      assert_equal false, result[:route_matched]
    end

    it 'returns route_matched: false for nil path' do
      result = subject.parse_input(nil)
      assert_equal false, result[:route_matched]
    end

    it 'returns route_matched: false for incomplete imgproxy paths' do
      assert_equal false, subject.parse_input('/insecure/')[:route_matched]
      assert_equal false, subject.parse_input('/insecure/rs:fill:200:200')[:route_matched]
      assert_equal false, subject.parse_input('/insecure/plain/')[:route_matched]
    end
  end

  describe 'successful parse' do
    it 'parses rs:fill with width, height, quality, and format' do
      result = subject.parse_input('/insecure/rs:fill:400:300/q:85/f:webp/plain/local:///assets/photo.jpg')
      assert_equal true, result[:route_matched]
      assert_equal({ fit: 'cover', width: '400', height: '300', quality: '85', format: 'webp' }, result[:req_params])
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'parses rs:fit and maps it to contain' do
      result = subject.parse_input('/insecure/rs:fit:200:150/plain/local:///assets/banner.jpg')
      assert_equal true, result[:route_matched]
      assert_equal 'contain', result[:req_params][:fit]
      assert_equal '200', result[:req_params][:width]
      assert_equal '150', result[:req_params][:height]
      assert_equal '/assets/banner.jpg', result[:asset_path]
    end

    it 'parses format from @ext suffix on the plain url' do
      result = subject.parse_input('/insecure/rs:fill:200:150/plain/local:///assets/banner.jpg@webp')
      assert_equal true, result[:route_matched]
      assert_equal 'webp', result[:req_params][:format]
      assert_equal '/assets/banner.jpg', result[:asset_path]
    end

    it 'parses discrete width and height options' do
      result = subject.parse_input('/insecure/w:500/h:350/q:90/dpr:2/plain/assets/image.png')
      assert_equal true, result[:route_matched]
      assert_equal({ width: '500', height: '350', quality: '90', dpr: '2' }, result[:req_params])
      assert_equal '/assets/image.png', result[:asset_path]
    end

    it 'parses long-form option names (resize, width, height, quality, format)' do
      result = subject.parse_input('/insecure/resize:fill:600:400/quality:75/format:avif/plain/local:///uploads/pic.jpeg')
      assert_equal true, result[:route_matched]
      assert_equal({ fit: 'cover', width: '600', height: '400', quality: '75', format: 'avif' }, result[:req_params])
      assert_equal '/uploads/pic.jpeg', result[:asset_path]
    end

    it 'parses background color' do
      result = subject.parse_input('/insecure/rs:fill:200:200/bg:white/plain/local:///assets/logo.png')
      assert_equal true, result[:route_matched]
      assert_equal 'white', result[:req_params][:background]
    end

    it 'handles custom cryptographic signature segment' do
      result = subject.parse_input('/a1b2c3d4e5f6/rs:fill:100:100/plain/local:///assets/avatar.jpg')
      assert_equal true, result[:route_matched]
      assert_equal '/assets/avatar.jpg', result[:asset_path]
      assert_equal 'cover', result[:req_params][:fit]
    end

    it 'handles plain http origin url' do
      result = subject.parse_input('/insecure/rs:fill:400:300/plain/http://localhost:3000/assets/photo.jpg')
      assert_equal true, result[:route_matched]
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'parses plain url without processing options' do
      result = subject.parse_input('/insecure/plain/local:///assets/photo.jpg@avif')
      assert_equal true, result[:route_matched]
      assert_equal({ format: 'avif' }, result[:req_params])
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'strips Rails asset digest fingerprint' do
      result = subject.parse_input('/insecure/w:100/plain/local:///assets/photo-1a2b3c4d.jpg')
      assert_equal '/assets/photo.jpg', result[:asset_path]
    end

    it 'strips 8-char hex fingerprint' do
      result = subject.parse_input('/insecure/w:100/plain/local:///assets/logo-deadbeef.png')
      assert_equal '/assets/logo.png', result[:asset_path]
    end

    it 'does not strip a non-fingerprint suffix' do
      result = subject.parse_input('/insecure/w:100/plain/local:///assets/photo-v2.jpg')
      assert_equal '/assets/photo-v2.jpg', result[:asset_path]
    end

    it 'handles webp and avif extensions' do
      assert_equal '/assets/image.webp', subject.parse_input('/insecure/w:100/plain/local:///assets/image.webp')[:asset_path]
      assert_equal '/assets/image.avif', subject.parse_input('/insecure/w:100/plain/local:///assets/image.avif')[:asset_path]
    end
  end
end
