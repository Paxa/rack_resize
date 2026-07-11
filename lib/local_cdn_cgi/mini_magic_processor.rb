require 'image_processing'

# require 'mini_magick'
# MiniMagick.logger.level = :debug

class LocalCdnCgi::MiniMagicProcessor
  def resize(source_file:, target_width:, target_height:, target_file: nil)
    image = ImageProcessing::MiniMagick.source(source_file)
    image = image.resize_to_limit(target_width, target_height) if target_width || target_height
    image = image.saver(quality: LocalCdnCgi.config.default_quality)

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
      img.quality(LocalCdnCgi.config.default_quality)

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

# magick /Users/pavel/Work/resume-io/app/assets/images/templates/vancouver.jpg -auto-orient -resize 426.0x> -quality 95 /Users/pavel/Work/resume-io/tmp/cdn_cgi_cache/60f2727cce350874040b321219f05766.jpg


# magick mogrify -resize 426.0x> /var/folders/n9/b__lxh7j1_xcwg4k_8j2_39m0000gp/T/mini_magick20260709-58478-qowydk.jpg
# magick mogrify -quality 95 /var/folders/n9/b__lxh7j1_xcwg4k_8j2_39m0000gp/T/mini_magick20260709-58478-qowydk.jpg
