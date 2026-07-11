require 'image_processing'

class LocalCdnCgi::VipsProcessor
  def resize(source_file:, target_file:, target_width:, target_height:)
    image = ImageProcessing::Vips.source(source_file)
    image = image.resize_to_limit(target_width, target_height) if target_width || target_height
    image = image.saver(quality: LocalCdnCgi.config.default_quality)

    # image.call(destination: target_file)

    if target_file
      image.call(destination: target_file)
    else
      begin
        tmp_file = image.call
        return tmp_file.read
      ensure
        tmp_file.unlink
      end
    end
  end
end
