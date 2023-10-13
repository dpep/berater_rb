package_name = Dir.glob('*.gemspec')[0].split('.')[0]
require "./lib/#{package_name}/version"

package = Berater


Gem::Specification.new do |s|
  s.name        = package_name
  s.version     = package.const_get 'VERSION'
  s.authors     = ['Daniel Pepper']
  s.summary     = package.to_s
  s.description = 'work...within limits'
  s.homepage    = "https://github.com/dpep/#{package_name}_rb"
  s.license     = 'MIT'

  s.files       = Dir.glob('lib/**/*')
  s.test_files  = Dir.glob('spec/**/*_spec.rb')

  s.required_ruby_version = '>= 3'

  s.add_runtime_dependency 'meddleware', '>= 0.3'
  s.add_runtime_dependency 'redis', '>= 3'

  s.add_development_dependency 'benchmark'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'codecov'
  s.add_development_dependency 'ddtrace', ENV['DDTRACE_VERSION']
  s.add_development_dependency 'dogstatsd-ruby', '>= 4.3'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'timecop'
end
