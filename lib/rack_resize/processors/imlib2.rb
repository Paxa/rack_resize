begin
  require "rszr"
rescue LoadError
  raise LoadError, "RackResize::Processors::Imlib2 requires the rszr gem. Please add `gem \"rszr\"` to your Gemfile."
end

class RackResize::Processors::Imlib2

  def resize(source_file:, target_file:, target_width:, target_height:, fit: nil, format: nil, quality: nil, bg_color: nil)
    quality ||= RackResize.config.default_quality
    cover = (fit == 'cover' || fit == 'crop') && target_width && target_height

    image = Rszr::Image.load(source_file)

    if target_width || target_height
      if cover
        target_w = target_width.to_i
        target_h = target_height.to_i
        src_w    = image.width
        src_h    = image.height

        if target_w.to_f / src_w >= target_h.to_f / src_h
          image.resize!(target_w, :auto)
          crop_y = [(image.height - target_h) / 2, 0].max
          image.crop!(0, crop_y, target_w, target_h)
        else
          image.resize!(:auto, target_h)
          crop_x = [(image.width - target_w) / 2, 0].max
          image.crop!(crop_x, 0, target_w, target_h)
        end
      else
        image.resize!(target_width || :auto, target_height || :auto)
      end
    end

    out_format = rszr_format(format || source_file.to_s)

    if target_file
      image.save(target_file)
      nil
    else
      image.save_data(format: out_format, quality: quality)
    end
  end

  private

  def rszr_format(format_or_path)
    case format_or_path.to_s.downcase
    when /\.png$/, 'png'   then :png
    when /\.webp$/, 'webp' then :webp
    when /\.gif$/, 'gif'   then :gif
    else :jpeg
    end
  end
end
