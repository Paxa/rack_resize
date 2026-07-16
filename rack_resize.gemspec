Gem::Specification.new do |s|
  s.name        = "rack_resize"
  s.version     = "0.1.2"
  s.author      = ["Pavel Evstigneev"]
  s.email       = ["pavel.evst@gmail.com"]
  s.homepage    = "https://github.com/paxa/rack_resize"
  s.summary     = %q{Image resizing on a fly}
  s.license     = 'MIT'
  s.required_ruby_version = ['>= 3.0']

  s.files       = `git ls-files`.split("\n")
  s.test_files  = []

  s.require_paths = ["lib"]

  s.add_runtime_dependency "rack", ["> 2.0", "< 4.0"]
end
