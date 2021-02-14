describe Berater::Inhibitor do
  describe '.new' do
    it 'initializes without any arguments or options' do
      expect(described_class.new).to be_a described_class
    end

    it 'initializes with any arguments and options' do
      expect(described_class.new(:abc, :def, x: 123)).to be_a described_class
    end

    it 'has default values' do
      expect(described_class.new.key).to be :inhibitor
      expect(described_class.new.redis).to be Berater.redis
    end
  end

  describe '#limit' do
    let(:limiter) { described_class.new }

    it 'always limits' do
      expect { limiter.limit }.to be_inhibited
    end
  end

end
