describe Berater::Utils do
  using Berater::Utils

  describe '.to_usec' do
    def f(val)
      (val * 10**6).to_i
    end

    it 'works with integers' do
      expect(0.to_usec).to be f(0)
      expect(3.to_usec).to be f(3)
    end

    it 'works with floats' do
      expect(0.1.to_usec).to be f(0.1)
      expect(3.0.to_usec).to be f(3)
    end

    it 'has great precision' do
      expect(0.123456.to_usec).to be 123456
      expect(123456.654321.to_usec).to be 123456654321
    end

    it 'works with symbols that are keywords' do
      expect(:sec.to_usec).to be f(1)
      expect(:second.to_usec).to be f(1)
      expect(:seconds.to_usec).to be f(1)

      expect(:min.to_usec).to be f(60)
      expect(:minute.to_usec).to be f(60)
      expect(:minutes.to_usec).to be f(60)

      expect(:hour.to_usec).to be f(60 * 60)
      expect(:hours.to_usec).to be f(60 * 60)
    end

    it 'works with strings that are keywords' do
      expect('sec'.to_usec).to be f(1)
      expect('second'.to_usec).to be f(1)
      expect('seconds'.to_usec).to be f(1)

      expect('min'.to_usec).to be f(60)
      expect('minute'.to_usec).to be f(60)
      expect('minutes'.to_usec).to be f(60)

      expect('hour'.to_usec).to be f(60 * 60)
      expect('hours'.to_usec).to be f(60 * 60)
    end

    it 'works with strings that are numeric' do
      expect('0'.to_usec).to be f(0)
      expect('3'.to_usec).to be f(3)

      expect('0.1'.to_usec).to be f(0.1)
      expect('3.0'.to_usec).to be f(3)
    end

    context 'with erroneous values' do
      def e(val)
        expect { val.to_usec }.to raise_error(ArgumentError)
      end

      it 'rejects negative numbers' do
        e(-1)
        e(-1.2)
        e('-1')
      end

      it 'rejects bogus symbols and strings' do
        e('abc')
        e('1a')
        e(:abc)
        e(Float::INFINITY)
      end
    end
  end

end
