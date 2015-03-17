# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'workshop_rack/version'

Gem::Specification.new do |spec|
  spec.name          = 'workshop_rack'
  spec.version       = WorkshopRack::VERSION
  spec.authors       = 'mdkalish'
  spec.email         = 'mdkalish4git@gmail.com'
  spec.summary       = 'Pilot Rack Workshop'
  spec.description   = 'Learn to build and test Rack app.'
  spec.homepage      = 'https://github.com/mdkalish/workshop_rack'
  spec.license       = ''
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.8'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_development_dependency 'rack-test', '~> 0.6'
  spec.add_development_dependency 'timecop', '~> 0.7'
  spec.add_development_dependency 'pry', '~> 0.10'
end
