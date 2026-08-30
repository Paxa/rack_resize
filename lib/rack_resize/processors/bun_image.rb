require "open3"
require "json"
require "tempfile"

class RackResize::Processors::BunImage
  SCRIPT = File.expand_path("bun_image.js", __dir__)

  def resize(source_file:, target_width:, target_height:, target_file: nil, fit: nil, format: nil, quality: nil, bg_color: nil)
    quality ||= RackResize.config.default_quality
    cover = (fit == 'cover' || fit == 'crop') && target_width && target_height

    # ponytail: Bun.Image has no crop/extract yet, so `cover` falls back to `fill`
    # (stretches to exact dims). Upgrade when Bun ships extract() or fit:"cover".
    bun_fit = cover ? 'fill' : 'inside'

    payload = {
      source:  source_file.to_s,
      target:  target_file&.to_s,
      width:   target_width&.to_i,
      height:  target_height&.to_i,
      format:  format && (format.to_s.downcase == 'jpg' ? 'jpeg' : format.to_s.downcase),
      quality: quality&.to_i,
      fit:     bun_fit,
    }

    if target_file
      run_bun(payload)
      nil
    else
      out, err, status = Open3.capture3("bun", SCRIPT, JSON.generate(payload))
      raise "bun_image failed: #{err}" unless status.success?
      out
    end
  end

  private

  def run_bun(payload)
    _, err, status = Open3.capture3("bun", SCRIPT, JSON.generate(payload))
    raise "bun_image failed: #{err}" unless status.success?
  end
end
