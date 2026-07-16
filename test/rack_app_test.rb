# frozen_string_literal: true

require_relative 'test_helper'

class RackAppTest < Minitest::Test
  UPSTREAM = ->(env) { [200, { 'content-type' => 'text/plain' }, ['upstream']] }

  def setup
    @tmpdir = Dir.mktmpdir('rack_resize_test')
    File.write(File.join(@tmpdir, 'photo.jpg'), 'fake jpeg content')

    @app = RackResize::RackApp.new(
      UPSTREAM,
      assets_folder: @tmpdir,
      processor:     :sips,
      save_resized:  false
    )

    fake_processing = Object.new
    def fake_processing.process!(**) = StringIO.new('processed image data')
    @app.instance_variable_set(:@processing, fake_processing)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- error_resp ---

  def test_error_resp_default_status
    status, headers, body = @app.error_resp('oops')
    assert_equal 404, status
    assert_equal({}, headers)
    assert_equal ['oops'], body
  end

  def test_error_resp_custom_status
    status, _, body = @app.error_resp('bad input', http_code: 422)
    assert_equal 422, status
    assert_equal ['bad input'], body
  end

  # --- send_file ---

  def test_send_file_returns_200_with_headers
    asset_file = Pathname.new(File.join(@tmpdir, 'photo.jpg'))
    content    = StringIO.new('hello')
    status, headers, _ = @app.send_file(asset_file:, file_content: content)

    assert_equal 200, status
    assert_equal 'image/jpeg', headers['content-type']
    assert_equal '5', headers['content-length']
    assert_equal 'inline', headers['content-disposition']
    assert_match(/\d+/, headers['cache-control'])
  end

  # --- pass-through for non-cdn-cgi paths ---

  def test_passes_through_unrelated_paths
    env    = Rack::MockRequest.env_for('/foo/bar.jpg')
    status, _, body = @app.call(env)
    assert_equal 200, status
    assert_equal ['upstream'], body
  end

  def test_passes_through_root_path
    env = Rack::MockRequest.env_for('/')
    _, _, body = @app.call(env)
    assert_equal ['upstream'], body
  end

  # --- path parsing errors ---

  def test_returns_404_for_unparseable_path
    env = Rack::MockRequest.env_for('/cdn-cgi/image/bad-path-no-extension')
    status, _, body = @app.call(env)
    assert_equal 404, status
    assert_equal ["can't parse file path"], body
  end

  def test_returns_404_for_path_traversal
    env = Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/../etc/photo.jpg')
    status, _, body = @app.call(env)
    assert_equal 404, status
    assert_equal ['.. is not allowed in image path'], body
  end

  def test_returns_404_for_missing_file
    env = Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/missing.jpg')
    status, _, body = @app.call(env)
    assert_equal 404, status
    assert_equal ['file not exists on a server'], body
  end

  # --- successful processing ---

  def test_returns_200_for_valid_request
    env = Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg')
    status, headers, _ = @app.call(env)
    assert_equal 200, status
    assert_equal 'image/jpeg', headers['content-type']
  end

  def test_valid_request_with_multiple_params
    env = Rack::MockRequest.env_for('/cdn-cgi/image/width=200,format=auto,quality=80/assets/photo.jpg')
    status, = @app.call(env)
    assert_equal 200, status
  end

  def test_response_body_is_processed_content
    env = Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg')
    _, headers, body = @app.call(env)
    assert_equal 'processed image data'.bytesize.to_s, headers['content-length']
  end

  # --- fingerprinted filenames (Rails asset digest) ---

  def test_strips_digest_fingerprint_from_filename
    File.write(File.join(@tmpdir, 'photo.jpg'), 'fake jpeg content')
    env = Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo-1a2b3c4d.jpg')
    status, _, _ = @app.call(env)
    assert_equal 200, status
  end

  # --- custom cf_path_prefix ---

  def test_custom_cf_path_prefix_does_not_intercept_default_prefix
    app = RackResize::RackApp.new(
      UPSTREAM,
      assets_folder:  @tmpdir,
      processor:      :sips,
      save_resized:   false,
      cf_path_prefix: '/img'
    )
    env = Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg')
    _, _, body = app.call(env)
    assert_equal ['upstream'], body
  end

  # --- without upstream app ---

  def test_initializes_without_upstream_app
    app = RackResize::RackApp.new(assets_folder: @tmpdir, processor: :sips, save_resized: false)
    assert_nil app.instance_variable_get(:@app)
  end
end
