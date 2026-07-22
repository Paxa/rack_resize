begin
  require "image_processing"
rescue LoadError
  raise LoadError, "RackResize::Processors::MiniMagick requires the image_processing gem. Please add `gem \"image_processing\"` to your Gemfile."
end

class RackResize::Processors::MiniMagick

  def resize(source_file:, target_width:, target_height:, target_file: nil, fit: nil, format: nil, quality: nil)
    quality ||= RackResize.config.default_quality
    cover = (fit == 'cover' || fit == 'crop') && target_width && target_height

    image = ImageProcessing::MiniMagick.source(source_file)
    image = image.convert(format) if format

    if target_width || target_height
      image = cover ? image.resize_to_fill(target_width, target_height)
                    : image.resize_to_limit(target_width, target_height)
    end

    image = image.saver(quality: quality)

    if target_file
      image.call(destination: target_file)
      nil
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
