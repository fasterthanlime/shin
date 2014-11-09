$:.push File.expand_path("../lib", __FILE__)
require "shin/version"

Gem::Specification.new do |s|
  s.name          = "shin"
  s.version       = Shin::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Amos Wenger"]
  s.email         = ["amos@lockfree.ch"]
  s.homepage      = "https://github.com/memoways/shin"
  s.summary       = %q{Something about s-exprs.}
  s.description   = %q{Something about s-exprs.}

  s.add_dependency 'treetop'

  s.require_paths = ["lib"]
  s.license = "MIT"
end
