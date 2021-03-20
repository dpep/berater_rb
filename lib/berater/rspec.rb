require 'berater'
require 'berater/rspec/matchers'
require 'berater/test_mode'
require 'rspec/core'

RSpec.configure do |config|
  config.include(Berater::Matchers)

  config.after do
    Berater.expunge rescue nil
    Berater.reset
  end
end
