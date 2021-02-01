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
    it 'works' do
      expect(described_class.new.limit).to be_nil
    end

    it 'yields' do
      expect {|b| described_class.new.limit(&b) }.to yield_control
    end

    it 'works no matter what' do
      expect(described_class.new(:key, 1, :second).limit).to be_nil
    end
  end

  describe 'Berater.limiter' do
    subject { Berater.limiter }

    it 'type is derived from the mode' do
      is_expected.to be_a described_class
    end

    it 'inherits redis' do
      expect(subject.redis).to be Berater.redis
    end

    it 'allows a new redis connection to be specified' do
      limiter = Berater.limiter(redis: :fake)
      expect(limiter.redis).not_to be Berater.redis
    end
  end

  describe 'Berater.limit' do
    it 'works' do
      expect(Berater.limit).to be_nil
    end

    it 'yields' do
      expect {|b| Berater.limit(&b) }.to yield_control
    end

    it 'never limits' do
      10.times { expect(Berater.limit { 123 } ).to eq 123 }
    end
  end

end
