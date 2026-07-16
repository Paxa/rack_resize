require "open3"

class RackResize::Processors::Sips

  def resize(source_file:, target_width:, target_height:, target_file: nil)
    args = %w[sips --deleteColorManagementProperties]
    args += ["-s", "formatOptions", RackResize.config.default_quality.to_s]

    if target_width && target_height
      info, status = Open3.capture2("sips", "-g", "pixelWidth", "-g", "pixelHeight", source_file.to_s)
      raise "sips failed to read dimensions for #{source_file}" unless status.success?
      src_w = info[/pixelWidth: (\d+)/, 1]&.to_f
      src_h = info[/pixelHeight: (\d+)/, 1]&.to_f
      if src_w && src_h && (target_width.to_f / src_w) <= (target_height.to_f / src_h)
        args += ["--resampleWidth", target_width.to_i.to_s]
      else
        args += ["--resampleHeight", target_height.to_i.to_s]
      end
    else
      args += ["--resampleWidth",  target_width.to_i.to_s]  if target_width
      args += ["--resampleHeight", target_height.to_i.to_s] if target_height
    end

    if target_file
      _, status = Open3.capture2(*args, "-o", target_file.to_s, source_file.to_s)
      raise "sips failed (exit #{status.exitstatus}) for #{source_file}" unless status.success?
      return nil
    end

    tmp = Tempfile.new(["result", File.extname(source_file)])
    tmp_path = tmp.path || raise("tempfile has no path")
    begin
      _, status = Open3.capture2(*args, "-o", tmp_path, source_file.to_s)
      raise "sips failed (exit #{status.exitstatus}) for #{source_file}" unless status.success?
      File.binread(tmp_path)
    ensure
      tmp.close
      tmp.unlink
    end
  end
end
