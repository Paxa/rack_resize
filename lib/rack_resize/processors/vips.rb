begin
  require "image_processing"
rescue LoadError
  raise LoadError, "RackResize::Processors::Vips requires the image_processing gem. Please add `gem \"image_processing\"` to your Gemfile."
end

class RackResize::Processors::Vips

  def resize(source_file:, target_file:, target_width:, target_height:)
    image = ImageProcessing::Vips.source(source_file)
    image = image.resize_to_limit(target_width, target_height) if target_width || target_height
    image = image.saver(quality: RackResize.config.default_quality)

    if target_file
      image.call(destination: target_file)
    else
      begin
        tmp_file = image.call
        return tmp_file.read
      ensure
        tmp_file&.unlink
      end
    end
  end
end
