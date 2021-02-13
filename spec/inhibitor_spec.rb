describe Berater::Inhibitor do
  describe '.new' do
    it 'initializes without any arguments or options' do
      expect(described_class.new).to be_a described_class
    end

    it 'initializes with any arguments and options' do
      expect(described_class.new(:abc, x: 123)).to be_a described_class
    end

    it 'has default values' do
      expect(described_class.new.key).to eq described_class.to_s
      expect(described_class.new.redis).to be Berater.redis
    end
  end

  describe '#limit' do
    let(:limiter) { described_class.new }

    it 'always limits' do
      expect { limiter }.to be_inhibited
    end

    it 'works with any options' do
      expect { limiter.limit(x: 123) }.to be_inhibited
    end
  end

end
