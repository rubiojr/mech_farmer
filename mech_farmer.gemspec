Gem::Specification.new do |s|
  s.name = %q{mech_farmer}
  s.version = "0.0.1"

  s.specification_version = 2 if s.respond_to? :specification_version=

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Sergio Rubio <sergio@rubio.name>"]
  s.date = %q{2008-10-29}
  #s.default_executable = %q{foo}
  s.description = %q{Script to farm info from servers}
  s.summary = %q{Library and utilities to analyse Apache logs}
  s.email = %q{sergio@rubio.name}
  s.executables = [ "mfarm" ]
  #s.extra_rdoc_files = ["README", "COPYING"]
  #s.has_rdoc = true
  s.homepage = %q{http://www.github.com/rubiojr/mech_farmer}
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.4")
  s.add_dependency(%q<term-ansicolor>, [">= 1.0"])
  s.add_dependency(%q<net-ssh>, [">= 2.0"])
  s.files = Dir["lib/**/*.rb"] #+ Dir["examples/*"]
end
