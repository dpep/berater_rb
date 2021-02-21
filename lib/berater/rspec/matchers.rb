module BeraterMatchers
  class Overloaded
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

          if res.is_a? Berater::Limiter
            # eg. expect { Berater.new(...) }.to be_overrated
            res.limit {}
          end
        when Berater::Limiter
          # eg. expect(Berater.new(...)).to be_overrated
          obj.limit {}
        end

        false
      rescue @type
        true
      end
    end

    # def description
    # it { expect { Berater.new(:inhibitor) }.not_to be_overrated }

    def failure_message
      "expected #{@type} to be raised"
    end

    def failure_message_when_negated
      "did not expect #{@type} to be raised"
    end
  end

  def be_overloaded
    Overloaded.new(Berater::Overloaded)
  end

  def be_overrated
    Overloaded.new(Berater::RateLimiter::Overrated)
  end

  def be_incapacitated
    Overloaded.new(Berater::ConcurrencyLimiter::Incapacitated)
  end

  def be_inhibited
    Overloaded.new(Berater::Inhibitor::Inhibited)
  end
end
