begin
  require "rszr"
rescue LoadError
  raise LoadError, "RackResize::Processors::Imlib2 requires the rszr gem. Please add `gem \"rszr\"` to your Gemfile."
end

class RackResize::Processors::Imlib2

  def resize(source_file:, target_file:, target_width:, target_height:)
    image = Rszr::Image.load(source_file)
    image.resize!(target_width || :auto, target_height || :auto) if target_width || target_height

    if target_file
      image.call(destination: target_file)
      image.save(target_file)
    else
      image.save_data(format: source_file.to_s =~ /\.png$/ ? :png : :jpeg)
    end
  end
end
