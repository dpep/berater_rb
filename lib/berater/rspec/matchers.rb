module Berater
  module Matchers
    class Overloaded
      def supports_block_expectations?
        true
      end

      def matches?(obj)
        case obj
        when Proc
          # eg. expect { ... }.to be_overloaded
          res = obj.call

          if res.is_a? Berater::Limiter
            # eg. expect { Berater.new(...) }.to be_overloaded
            @limiter = res
            @limiter.utilization >= 100
          else
            # eg. expect { Berater(...)  }.to be_overloaded
            # eg. expect { limiter.limit }.to be_overloaded
            false
          end
        when Berater::Limiter
          # eg. expect(Berater.new(...)).to be_overloaded
          @limiter = obj
          @limiter.utilization >= 100
        end
      rescue Berater::Overloaded
        true
      end

      def description
        if @limiter
          "be overloaded"
        else
          "raise #{Berater::Overloaded}"
        end
      end

      def failure_message
        if @limiter
          "expected to be overloaded"
        else
          "expected #{Berater::Overloaded} to be raised"
        end
      end

      def failure_message_when_negated
        if @limiter
          "expected not to be overloaded"
        else
          "did not expect #{Berater::Overloaded} to be raised"
        end
      end
    end

    def be_overloaded
      Overloaded.new
    end
  end
end
