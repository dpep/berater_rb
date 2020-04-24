$LOAD_PATH.unshift 'lib'
package_name = 'berater'
require "#{package_name}"
package = Object.const_get package_name.capitalize


Gem::Specification.new do |s|
  s.name        = package_name
  s.version     = package.const_get 'VERSION'
  s.authors     = ['Daniel Pepper']
  s.summary     = package.to_s
  s.description = 'rate limiter'
  s.homepage    = "https://github.com/dpep/#{package_name}"
  s.license     = 'MIT'

  s.files       = Dir.glob('lib/**/*')
  s.test_files  = Dir.glob('test/**/test_*')

  s.add_runtime_dependency 'redis'
  s.add_development_dependency 'clockwork'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
end
