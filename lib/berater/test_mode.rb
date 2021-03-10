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

  module TestMode
    def acquire_lock(*)
      case Berater.test_mode
      when :pass
        Lock.new(Float::INFINITY, 0)
      when :fail
        # find class specific Overloaded error
        e = self.class.constants.map do |name|
          self.class.const_get(name)
        end.find do |const|
          const.is_a?(Class) && const < Berater::Overloaded
        end || Berater::Overloaded

        raise e
      else
        super
      end
    end
  end

end

# stub each Limiter subclass
ObjectSpace.each_object(Class).each do |klass|
  next unless klass < Berater::Limiter

  klass.prepend(Berater::TestMode)
end
