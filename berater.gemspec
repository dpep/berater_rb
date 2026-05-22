require_relative 'lib/berater/version'

Gem::Specification.new do |s|
  s.name        = 'berater'
  s.version     = Berater::VERSION
  s.authors     = ['Daniel Pepper']
  s.summary     = 'Berater'
  s.description = 'work...within limits'
  s.homepage    = 'https://github.com/dpep/berater_rb'
  s.license     = 'MIT'
  s.files       = `git ls-files * ':!:spec'`.split("\n")

  s.required_ruby_version = '>= 3'

  s.add_runtime_dependency 'meddleware', '>= 0.3'
  s.add_runtime_dependency 'redis', '>= 3'

  s.add_development_dependency 'benchmark'
  s.add_development_dependency 'debug'
  s.add_development_dependency 'datadog', '>= 2'
  s.add_development_dependency 'dogstatsd-ruby', '>= 4.3'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'timecop'
end
