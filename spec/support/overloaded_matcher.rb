module OverratedMatchers
  class BeOverrated
    def initialize(type)
      @type = type
    end

    def supports_block_expectations?
      true
    end

    def matches?(obj)
      begin
        case obj
        when Proc
          # eg. expect { ... }.to be_overrated
          res = obj.call

          if res.is_a? Berater::BaseLimiter
            # eg. expect { Berater.new(...) }.to be_overrated
            res.limit {}
          end
        when Berater::BaseLimiter
          # eg. expect(Berater.new(...)).to be_overrated
          obj.limit {}
        end

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

  def be_inhibited
    BeOverrated.new(Berater::Inhibitor::Inhibited)
  end
end

RSpec::configure do |config|
  config.include(OverratedMatchers)
end
