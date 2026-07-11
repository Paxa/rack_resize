require "open3"
require "shellwords"

class LocalCdnCgi::SipsProcessor
  def resize(source_file:, target_width:, target_height:, target_file: nil)
    args = ["sips"]
    args << "--resampleWidth" << target_width.to_i if target_width
    args << "--resampleHeight" << target_height.to_i if target_height

    if target_file
      args << "-o" << Shellwords.escape(target_file)
    else
      tmp_file = Tempfile.new(["result", File.extname(source_file)])
      args << "-o" << tmp_file.path
    end

    args << Shellwords.escape(source_file)

    # sips -Z 1200 input.jpg

    pp [:args, args, args.join(" ")]

    p `#{args.join(" ")}`

    # stdout, stderr, status = Open3.capture3(args)
    # puts "stdout: #{stdout}"
    # puts "stderr: #{stderr}"
    # puts "status: #{status}"

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
