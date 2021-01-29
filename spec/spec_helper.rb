# $LOAD_PATH.unshift 'lib'

require 'berater'
require 'byebug'
require 'redis'
require 'timecop'

class Numeric
  def seconds; self; end
  alias :second :seconds

  def minutes; self * 60; end
  alias :minute :minutes

  def hours; self * 3600; end
  alias :hour :hours

  def days; self * 86400; end
  alias :day :days
end


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

