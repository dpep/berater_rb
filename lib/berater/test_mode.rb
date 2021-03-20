require 'berater'

module Berater

  module TestMode
    attr_reader :test_mode

    def test_mode=(mode)
      unless [ nil, :pass, :fail ].include?(mode)
        raise ArgumentError, "invalid mode: #{Berater.test_mode}"
      end

      @test_mode = mode
    end

    def reset
      super
      @test_mode = nil
    end
  end

  class Limiter
    module TestMode
      def acquire_lock(*)
        case Berater.test_mode
        when :pass
          Lock.new(Float::INFINITY, 0)
        when :fail
          raise Overloaded
        else
          super
        end
      end
    end
  end

end

# prepend class methods
Berater.singleton_class.prepend Berater::TestMode

# stub each Limiter subclass
ObjectSpace.each_object(Class).each do |klass|
  next unless klass < Berater::Limiter

  klass.prepend Berater::Limiter::TestMode
end
