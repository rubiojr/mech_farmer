Gem::Specification.new do |s|
  s.name = %q{mech_farmer}
  s.version = "0.0.7"

  s.specification_version = 2 if s.respond_to? :specification_version=

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Sergio Rubio <sergio@rubio.name>"]
  s.date = %q{2008-10-29}
  #s.default_executable = %q{foo}
  s.description = %q{Script to farm info from servers}
  s.summary = %q{Library and utilities to analyse Apache logs}
  s.email = %q{sergio@rubio.name}
  s.executables = [ 'mfarmer', 'mf_host_report', 'mf_check_sshd_secured',
                    'mf_check_bad_ssh_pubkeys']
  #s.extra_rdoc_files = ["README", "COPYING"]
  #s.has_rdoc = true
  s.homepage = %q{http://www.github.com/rubiojr/mech_farmer}
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.4")
  s.add_dependency(%q<term-ansicolor>, [">= 1.0"])
  s.add_dependency(%q<net-ssh>, [">= 2.0"])
  s.add_dependency(%q<ip>, [">= 0.2"])
  s.add_dependency(%q<net-ping>, [">= 1.2"])
  s.files = Dir["lib/**/*.rb"] #+ Dir["examples/*"]
end
