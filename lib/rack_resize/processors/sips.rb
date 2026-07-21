require "open3"

class RackResize::Processors::Sips

  def resize(source_file:, target_width:, target_height:, target_file: nil, fit: nil, format: nil, quality: nil)
    quality ||= RackResize.config.default_quality
    cover = (fit == 'cover' || fit == 'crop') && target_width && target_height

    args = %w[sips --deleteColorManagementProperties]
    args += ["-s", "format", sips_format(format)] if format
    args += ["-s", "formatOptions", quality.to_s]

    if target_width && target_height
      src_w, src_h = sips_dimensions(source_file)
      if cover
        if target_width.to_f / src_w >= target_height.to_f / src_h
          args += ["--resampleWidth", target_width.to_i.to_s]
        else
          args += ["--resampleHeight", target_height.to_i.to_s]
        end
      elsif src_w && src_h
        if (target_width.to_f / src_w) <= (target_height.to_f / src_h)
          args += ["--resampleWidth", target_width.to_i.to_s]
        else
          args += ["--resampleHeight", target_height.to_i.to_s]
        end
      end
    else
      args += ["--resampleWidth",  target_width.to_i.to_s]  if target_width
      args += ["--resampleHeight", target_height.to_i.to_s] if target_height
    end

    if target_file
      run_sips(*args, "-o", target_file.to_s, source_file.to_s)
      sips_crop!(target_file.to_s, target_width, target_height) if cover
      nil
    else
      tmp = Tempfile.new(["result", File.extname(source_file)])
      begin
        run_sips(*args, "-o", tmp.path, source_file.to_s)
        sips_crop!(tmp.path, target_width, target_height) if cover
        File.binread(tmp.path)
      ensure
        tmp.close
        tmp.unlink
      end
    end
  end

  private

  def sips_dimensions(source_file)
    info, status = Open3.capture2("sips", "-g", "pixelWidth", "-g", "pixelHeight", source_file.to_s)
    raise "sips failed to read dimensions for #{source_file}" unless status.success?
    [info[/pixelWidth: (\d+)/, 1]&.to_f, info[/pixelHeight: (\d+)/, 1]&.to_f]
  end

  def run_sips(*args)
    _, status = Open3.capture2(*args)
    raise "sips failed (exit #{status.exitstatus}): #{args.join(' ')}" unless status.success?
  end

  def sips_crop!(path, width, height)
    run_sips("sips", "--cropToHeightWidth", height.to_i.to_s, width.to_i.to_s, path)
  end

  def sips_format(format)
    format.to_s.downcase == 'jpg' ? 'jpeg' : format.to_s.downcase
  end
end
