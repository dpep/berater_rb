require 'byebug'
require 'redis'
require 'rspec'
require 'rspec/matchers/fail_matchers'
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
require 'berater/rspec'

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.before do
    Berater.configure do |c|
      c.redis = Redis.new
    end
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

  # reduce noise in backtraces
  config.filter_gems_from_backtrace('timecop')

  # expect { ... }.to fail
  config.include RSpec::Matchers::FailMatchers
end
