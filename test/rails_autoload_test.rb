require_relative 'test_helper'
require 'rails'
require 'rack_resize/rails_autoload'

SAMPLES_DIR = Pathname.new(__dir__).join('../samples').expand_path

# ---------------------------------------------------------------------------
# Real minimal Rails application, initialized once for the entire test file.
# The root directory mirrors the standard Rails directory structure so that
# Configuration defaults (assets/uploads folders, cache dir) are testable.
# ---------------------------------------------------------------------------
RAILS_TEST_ROOT = Pathname.new(Dir.mktmpdir('rack_resize_rails_app'))
Minitest.after_run { FileUtils.rm_rf(RAILS_TEST_ROOT) }

FileUtils.mkdir_p(RAILS_TEST_ROOT.join('app', 'assets', 'images'))
FileUtils.mkdir_p(RAILS_TEST_ROOT.join('public', 'uploads'))
FileUtils.mkdir_p(RAILS_TEST_ROOT.join('tmp'))
FileUtils.cp(SAMPLES_DIR.join('image_1.jpeg'),
             RAILS_TEST_ROOT.join('app', 'assets', 'images', 'photo.jpg'))
FileUtils.cp(SAMPLES_DIR.join('sample.png'),
             RAILS_TEST_ROOT.join('public', 'uploads', 'avatar.png'))

class RackResizeTestApp < Rails::Application
  config.root            = RAILS_TEST_ROOT
  config.eager_load      = false
  config.secret_key_base = 'test_secret_key_base_for_rack_resize_tests'
  config.logger          = Logger.new(nil)
  config.log_level       = :warn
end

RackResizeTestApp.initialize!

describe 'RackResize Rails integration' do
  describe 'RackResize::Railtie' do
    it 'is a Rails::Railtie subclass' do
      assert_includes RackResize::Railtie.ancestors, Rails::Railtie
    end

    it 'has an initializer named rack_resize.auto_register_itself' do
      names = RackResize::Railtie.initializers.map(&:name)
      assert_includes names, 'rack_resize.auto_register_itself'
    end

    it 'inserts RackResize::RackApp at position 0 in the middleware stack' do
      middlewares = Rails.application.config.middleware.map(&:klass)
      assert_equal RackResize::RackApp, middlewares.first
    end
  end

  describe 'RackResize::Configuration Rails defaults' do
    it 'sets cache_folder to Rails.root/tmp/rack_resize_cache' do
      config = RackResize::Configuration.new
      assert_equal Rails.root.join('tmp', 'rack_resize_cache'), config.cache_folder
    end

    it 'enables save_resized by default' do
      config = RackResize::Configuration.new
      assert config.save_resized?
    end

    it 'respects an explicit save_resized: false option' do
      config = RackResize::Configuration.new(save_resized: false)
      refute config.save_resized?
    end

    it 'maps /assets to Rails.root/app/assets/images' do
      config = RackResize::Configuration.new
      assert_equal Rails.root.join('app/assets/images'), config.assets_folders['/assets']
    end

    it 'maps /uploads to Rails.root/public/uploads' do
      config = RackResize::Configuration.new
      assert_equal Rails.root.join('public/uploads'), config.assets_folders['/uploads']
    end

    it 'allows cache_folder to be overridden explicitly' do
      custom = Pathname.new('/tmp/custom_cache')
      config = RackResize::Configuration.new(cache_folder: custom)
      assert_equal custom, config.cache_folder
    end

    it 'does not overwrite explicit assets_folders with Rails defaults' do
      custom_dir = RAILS_TEST_ROOT.join('custom')
      config = RackResize::Configuration.new(assets_folders: { 'custom' => custom_dir })
      assert_equal ['/custom'], config.assets_folders.keys
    end

    it 'uses Rails.logger when no logger is configured' do
      processing = RackResize::Processing.new(config: RackResize::Configuration.new)
      assert_equal Rails.logger, processing.logger
    end

    it 'uses an explicitly configured logger over Rails.logger' do
      custom_logger = Logger.new(nil)
      config = RackResize::Configuration.new(logger: custom_logger)
      processing = RackResize::Processing.new(config: config)
      assert_equal custom_logger, processing.logger
    end
  end

  describe 'end-to-end middleware request' do
    def build_middleware(processor: :imlib2, save_resized: false, extra_opts: {})
      RackResize::RackApp.new(
        ->(env) { [200, {}, ['upstream']] },
        processor:      processor,
        save_resized:   save_resized,
        assets_folders: {
          'assets'  => Rails.root.join('app', 'assets', 'images'),
          'uploads' => Rails.root.join('public', 'uploads'),
        },
        **extra_opts
      )
    end

    def image_dimensions(body, ext: '.jpg')
      Tempfile.create(['dim_check', ext]) do |f|
        f.binmode; f.write(body.read); f.flush; f.close
        img = Rszr::Image.load(f.path)
        [img.width, img.height]
      end
    end

    it 'serves a resized JPEG from the assets folder' do
      status, headers, body = build_middleware.call(
        Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg')
      )
      assert_equal 200, status
      assert_equal 'image/jpeg', headers['content-type']
      w, = image_dimensions(body)
      assert_equal 100, w
    end

    it 'serves a resized PNG from the uploads folder' do
      status, headers, body = build_middleware.call(
        Rack::MockRequest.env_for('/cdn-cgi/image/width=48/uploads/avatar.png')
      )
      assert_equal 200, status
      assert_equal 'image/png', headers['content-type']
      w, = image_dimensions(body, ext: '.png')
      assert_equal 48, w
    end

    it 'resizes within a box when width and height are both given' do
      status, _, body = build_middleware.call(
        Rack::MockRequest.env_for('/cdn-cgi/image/width=150,height=100/assets/photo.jpg')
      )
      assert_equal 200, status
      w, h = image_dimensions(body)
      assert_operator w, :<=, 150
      assert_operator h, :<=, 100
    end

    it 'returns 404 for a path outside configured folders' do
      status, = build_middleware.call(
        Rack::MockRequest.env_for('/cdn-cgi/image/width=100/other/photo.jpg')
      )
      assert_equal 404, status
    end

    it 'returns 404 for a missing file' do
      status, = build_middleware.call(
        Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/missing.jpg')
      )
      assert_equal 404, status
    end

    it 'caches processed images when save_resized is true' do
      cache_dir = Rails.root.join('tmp', 'rack_resize_cache')
      app = build_middleware(save_resized: true, extra_opts: { cache_folder: cache_dir })
      app.call(Rack::MockRequest.env_for('/cdn-cgi/image/width=100/assets/photo.jpg'))
      cached = Dir.glob("#{cache_dir}/**/*").select { |f| File.file?(f) }
      assert_operator cached.size, :>, 0
    end

    it 'passes non-image requests through to upstream' do
      _, _, body = build_middleware.call(Rack::MockRequest.env_for('/some/other/path'))
      assert_equal ['upstream'], body
    end
  end
end
