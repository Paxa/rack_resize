begin
  require "image_processing"
rescue LoadError
  raise LoadError, "RackResize::Processors::MiniMagick requires the image_processing gem. Please add `gem \"image_processing\"` to your Gemfile."
end

# require 'mini_magick'
# MiniMagick.logger.level = :debug

class RackResize::Processors::MiniMagick

  def resize(source_file:, target_width:, target_height:, target_file: nil)
    image = ImageProcessing::MiniMagick.source(source_file)
    image = image.resize_to_limit(target_width, target_height) if target_width || target_height
    image = image.saver(quality: RackResize.config.default_quality)

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

  def resize_mm(source_file:, target_width:, target_height:, target_file: nil)
    image = MiniMagick::Image.open(source_file)
    image.combine_options do |img|
      img.resize("#{target_width}x#{target_height}>") if target_width || target_height
      img.quality(RackResize.config.default_quality)

      if target_file
        img.write(target_file)
      end
    end

    unless target_file
      return File.open(image.path, 'rb', &:read)
    end

  ensure
    image&.destroy!
  end
end
