require "shellwords"

class RackResize::Processors::Sips

  def resize(source_file:, target_width:, target_height:, target_file: nil)
    # args = ["sips", "--deleteColorManagementProperties", "--optimizeColorForSharing"]
    args = ["sips", "--deleteColorManagementProperties", "--debug"]
    args += ["-s formatOptions", RackResize.config.default_quality]
    args << "--resampleWidth" << target_width.to_i if target_width
    args << "--resampleHeight" << target_height.to_i if target_height

    if target_file
      args << "-o" << Shellwords.escape(target_file)
    else
      tmp_file = Tempfile.new(["result", File.extname(source_file)])
      args << "-o" << tmp_file.path
    end

    args << Shellwords.escape(source_file)

    pp [:args, args, args.join(" ")]

    result = `#{args.join(" ")}`

    puts "sips command result: #{result}"

    unless target_file
      begin
        return File.open(tmp_file.path, 'rb', &:read)
      ensure
        tmp_file.unlink
      end
    end

    nil
  end
end
