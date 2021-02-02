describe Berater::Unlimiter do
  before { Berater.mode = :unlimited }

  describe '.new' do
    it 'initializes with any arguments and options' do
      expect(described_class.new(:abc, x: 123)).to be_a described_class
    end

    it 'initializes without any arguments or options' do
      expect(described_class.new).to be_a described_class
    end
  end

  describe '.limit' do
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
  end

end
