require 'byebug'
require 'redis'
require 'simplecov'
require 'timecop'

SimpleCov.start do
  add_filter '/spec/'
end

if ENV['CI'] == 'true' || ENV['CODECOV_TOKEN']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require 'berater'

RSpec.configure do |config|
  config.before do
    Berater.configure Redis.new
    Berater.redis.flushall
  end

  # allow 'fit' examples
  config.filter_run_when_matching :focus

  config.around(:each) do |example|
    # only with blocks
    Timecop.safe_mode = true

    # Freeze time by default
    Timecop.freeze do
      example.run
    end
  end
end
