require 'berater'

module Berater
  extend self

  attr_reader :test_mode

  def test_mode=(mode)
    unless [ nil, :pass, :fail ].include?(mode)
      raise ArgumentError, "invalid mode: #{Berater.test_mode}"
    end

    @test_mode = mode

    # overload class methods
    unless Berater::Limiter.singleton_class.ancestors.include?(TestMode)
      Berater::Limiter.singleton_class.prepend(TestMode)
    end
  end

  module TestMode
    def new(*args, **opts)
      return super unless Berater.test_mode

      # stub desired behavior
      super.tap do |instance|
        instance.define_singleton_method(:acquire_lock) do |*|
          case Berater.test_mode
          when :pass
            Lock.new(Float::INFINITY, 0)
          when :fail
            # find class specific Overloaded error
            e = self.class.constants.map do |name|
              self.class.const_get(name)
            end.find do |const|
              const < Berater::Overloaded
            end || Berater::Overloaded

            raise e
          end
        end
      end
    end
  end

end
