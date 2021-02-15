describe Berater::Unlimiter do
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
    let(:limiter) { described_class.new }

    it 'works' do
      expect {|b| limiter.limit(&b) }.to yield_control
    end

    it 'works without a block' do
      expect(limiter.limit).to be_a Berater::Lock
    end

    it 'is never overloaded' do
      10.times do
        expect { limiter.limit }.not_to be_overloaded
      end
    end
  end

  it_behaves_like 'a lock', described_class.new

end
