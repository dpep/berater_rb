require 'berater'

module Berater
  extend self

  attr_reader :test_mode

  def test_mode=(mode)
    unless [ nil, :pass, :fail ].include?(mode)
      raise ArgumentError, "invalid mode: #{Berater.test_mode}"
    end

    @test_mode = mode
  end

  class Limiter
    def self.new(*args, **opts)
      return super unless Berater.test_mode

      # chose a stub class with desired behavior
      stub_klass = case Berater.test_mode
      when :pass
        Berater::Unlimiter
      when :fail
        Berater::Inhibitor
      end

      # don't stub self
      return super if self < stub_klass

      # swap out limit method with stub
      super.tap do |instance|
        stub = stub_klass.allocate
        stub.send(:initialize, *args, **opts)

        instance.define_singleton_method(:limit) do |**opts, &block|
          stub.limit(**opts, &block)
        end

        instance.define_singleton_method(:overloaded?) do
          stub.overloaded?
        end
      end
    end
  end

end
