describe Berater::Unlimiter do
  it_behaves_like 'a limiter', described_class.new

  describe '.new' do
    it 'initializes without any arguments or options' do
      expect(described_class.new).to be_a described_class
    end

    it 'initializes with any arguments and options' do
      expect(described_class.new(:abc, :def, x: 123)).to be_a described_class
    end

    it 'has default values' do
      expect(described_class.new.key).to be :unlimiter
      expect(described_class.new.redis).to be Berater.redis
    end
  end

  describe '#limit' do
    subject { described_class.new }

    it_behaves_like 'it is not overloaded'

    it 'is never overloaded' do
      10.times do
        expect { subject.limit }.not_to be_overloaded
      end
    end
  end
end
