require 'byebug'
require 'redis'
require 'rspec'
require 'rspec/matchers/fail_matchers'
require 'simplecov'
require 'timecop'

SimpleCov.start do
  add_filter /spec/
end

if ENV['CI'] == 'true' || ENV['CODECOV_TOKEN']
  require 'simplecov_json_formatter'
  SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
end

require 'berater'
require 'berater/rspec'

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  # allow 'fit' examples
  config.filter_run_when_matching :focus

  # reduce noise in backtraces
  config.filter_gems_from_backtrace('timecop')

  # expect { ... }.to fail
  config.include RSpec::Matchers::FailMatchers

  config.mock_with :rspec do |mocks|
    # verify existence of stubbed methods
    mocks.verify_partial_doubles = true
  end

  redis = Redis.new

  config.before do
    Berater.configure do |c|
      c.redis = redis
    end
  end

  config.around(:each) do |example|
    # only with blocks
    Timecop.safe_mode = true

    # Freeze time by default
    Timecop.freeze do
      example.run
    end
  end

  config.after do
    Berater.redis.script(:flush) rescue nil
  end
end
