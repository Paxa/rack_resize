# frozen_string_literal: true
#
# Direct processor benchmark: instantiates each available RackResize processor
# and calls resize() directly on images from the samples/ folder.
#
# Usage:
#   bundle exec ruby benchmark/processor_benchmark.rb

require 'bundler/setup'
require 'benchmark/ips'
require_relative '../lib/rack_resize'

SAMPLES_DIR   = File.expand_path('../samples', __dir__)
BENCH_IMAGES  = Dir[File.join(SAMPLES_DIR, '{image_1,sample}.{jpg,jpeg,png,webp,heic,avif}')].sort
BENCH_WIDTH   = 300
BENCH_HEIGHT  = 200

abort 'No sample images found in samples/.' if BENCH_IMAGES.empty?

# ── Collect available processor instances ────────────────────────────────────

PROCESSOR_CLASSES = {
  sips:        RackResize::Processors::Sips,
  vips:        RackResize::Processors::Vips,
  mini_magick: RackResize::Processors::MiniMagick,
  imlib2:      RackResize::Processors::Imlib2,
}.freeze

puts "Loading processors..."
processors = {}

PROCESSOR_CLASSES.each do |name, klass|
  begin
    instance = klass.new
    # Verify the processor actually works before including it
    instance.resize(
      source_file:   BENCH_IMAGES.first,
      target_file:   nil,
      target_width:  BENCH_WIDTH,
      target_height: BENCH_HEIGHT,
    )
    processors[name] = instance
    puts "  ✓ #{name}"
  rescue => e
    puts "  ✗ #{name}: #{e.message}"
  end
end

abort "\nNo processors available." if processors.empty?

puts "\nSample images: #{BENCH_IMAGES.map { |f| File.basename(f) }.join(', ')}"

# ── Benchmark each sample image independently ─────────────────────────────────

BENCH_IMAGES.each do |image_path|
  image_name = File.basename(image_path)
  image_size = File.size(image_path)

  puts "\n── Direct processor benchmark ───────────────────────────────────────────────"
  puts "   image : #{image_name} (#{image_size / 1024} KB)"
  puts "   output: #{BENCH_WIDTH}x#{BENCH_HEIGHT}"
  puts

  Benchmark.ips do |x|
    x.config(time: 5, warmup: 2)

    processors.each do |name, processor|
      next if name.to_s == "imlib2" && image_name =~ /heic|webp|avif/
      next if name.to_s == "sips" && image_name =~ /webp/

      x.report(name.to_s) do
        processor.resize(
          source_file:   image_path,
          target_file:   nil,
          target_width:  BENCH_WIDTH,
          target_height: BENCH_HEIGHT,
        )
      end
    end

    x.compare!
  end
end
