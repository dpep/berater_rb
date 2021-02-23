require 'berater'
require 'berater/rspec/matchers'
require 'berater/test_mode'
require 'rspec'

RSpec.configure do |config|
  config.include(BeraterMatchers)

  config.after do
    Berater.expunge rescue nil
    Berater.redis.script(:flush) rescue nil
  end
end
