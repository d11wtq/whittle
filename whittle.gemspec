# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "whittle/version"

Gem::Specification.new do |s|
  s.name        = "whittle"
  s.version     = Whittle::VERSION
  s.authors     = ["d11wtq"]
  s.email       = ["chris@w3style.co.uk"]
  s.homepage    = "https://github.com/d11wtq/whittle"
  s.summary     = %q{An efficient, easy to use, LALR parser for Ruby}
  s.description = %q{Write powerful parsers by defining a series of very simple rules
                     and operations to perform as those rules are matched.  Whittle
                     parsers are written in pure ruby and as such are extremely flexible.
                     Anybody familiar with parsers like yacc should find Whittle intuitive.
                     Those unfamiliar with parsers shouldn't find it difficult to
                     understand.}

  s.rubyforge_project = "whittle"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec", "~> 2.6"
end
