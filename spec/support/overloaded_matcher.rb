module OverratedMatchers
  class BeOverrated
    def initialize(type)
      @type = type
    end

    def supports_block_expectations?
      true
    end

    def matches?(block)
      begin
        block.call
        false
      rescue @type
        true
      end
    end

    # def description

    def failure_message
      "expected #{@type} to be raised"
    end

    def failure_message_when_negated
      "did not expect #{@type} to be raised"
    end
  end

  def be_overloaded
    BeOverrated.new(Berater::Overloaded)
  end

  def be_overrated
    BeOverrated.new(Berater::RateLimiter::Overrated)
  end

  def be_incapacitated
    BeOverrated.new(Berater::ConcurrencyLimiter::Incapacitated)
  end
end

RSpec::configure do |config|
  config.include(OverratedMatchers)
end
