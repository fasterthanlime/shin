$:.push File.expand_path("../lib", __FILE__)
require "shin/version"

Gem::Specification.new do |spec|
  spec.name          = "shin"
  spec.version       = Shin::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Amos Wenger", "Nicolas Goy"]
  spec.email         = ["amos@memoways.com", "nicolas@memoways.com"]
  spec.homepage      = "https://github.com/memoways/shin"
  spec.summary       = %q{A ClojureScript-inspired language that compiles to JavaScript.}
  spec.homepage      = "https://github.com/memoways/shin"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_dependency "oj", "~> 2.11.1"
  spec.add_dependency "therubyracer", "~> 0.12.1"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "pry", "~> 0.10.1"
  spec.add_development_dependency "rspec", "~> 3.1.0"
end
