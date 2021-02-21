require 'berater'
require 'berater/rspec/matchers'
require 'rspec'

RSpec.configure do |config|
  config.include(BeraterMatchers)

  config.after do
    Berater.expunge rescue nil
  end
end
