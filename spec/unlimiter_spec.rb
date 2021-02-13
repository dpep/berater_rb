describe Berater::Unlimiter do
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

  describe '.limit' do
    it 'works' do
      expect(described_class.limit).to be_nil
    end

    it 'yields' do
      expect {|b| described_class.limit(&b) }.to yield_control
    end

    it 'is never overloaded' do
      10.times do
        expect { described_class.limit }.not_to be_overloaded
      end
    end

    it 'works with any arguments or options' do
      expect(described_class.limit(:abc, x: 123)).to be_nil
    end
  end

  describe '#limit' do
    let(:limiter) { described_class.new }

    it 'works' do
      expect(limiter.limit).to be_nil
    end

    it 'yields' do
      expect {|b| limiter.limit(&b) }.to yield_control
    end

    it 'is never overloaded' do
      10.times do
        expect { limiter.limit }.not_to be_overloaded
      end
    end

    it 'works with any arguments or options' do
      expect(limiter.limit(x: 123)).to be_nil
    end
  end

end
