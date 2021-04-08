describe Berater::LimiterSet do
  subject { described_class.new }

  let(:unlimiter) { Berater::Unlimiter.new }
  let(:inhibitor) { Berater::Inhibitor.new }

  describe '#each' do
    it 'returns an Enumerator' do
      expect(subject.each).to be_a Enumerator
    end

    it 'works with an empty set' do
      expect(subject.each.to_a).to eq []
    end

    it 'returns elements' do
      subject << unlimiter
      expect(subject.each.to_a).to eq [ unlimiter ]
    end
  end

  describe '#<<' do
    it 'adds a limiter' do
      subject << unlimiter
      expect(subject.each.to_a).to eq [ unlimiter ]
    end

    it 'rejects things that are not limiters' do
      expect {
        subject << :foo
      }.to raise_error(ArgumentError)
    end

    it 'updates existing keys' do
      limiter = Berater::Unlimiter.new
      expect(limiter).to eq unlimiter
      expect(limiter).not_to be unlimiter

      subject << unlimiter
      subject << limiter

      expect(subject.each.to_a).to eq [ limiter ]
    end
  end

  describe '[]=' do
    it 'adds a limiter' do
      subject[:key] = unlimiter

      expect(subject.each.to_a).to eq [ unlimiter ]
      is_expected.to include :key
      is_expected.to include unlimiter
    end

    it 'rejects things that are not limiters' do
      expect {
        subject[:key] = :foo
      }.to raise_error(ArgumentError)
    end
  end

  describe '#[]' do
    it 'returns nil for missing keys' do
      expect(subject[:key]).to be nil
      expect(subject[nil]).to be nil
    end

    it 'retreives limiters' do
      subject << unlimiter
      expect(subject[unlimiter.key]).to be unlimiter
    end
  end

  describe '#fetch' do
    it 'raises for missing keys' do
      expect {
        subject.fetch(:key)
      }.to raise_error(KeyError)

      expect {
        subject.fetch(nil)
      }.to raise_error(KeyError)
    end

    it 'returns the default if provided' do
      expect(subject.fetch(:key, unlimiter)).to be unlimiter
    end

    it 'calls the default proc if provided' do
      expect {|block| subject.fetch(:key, &block) }.to yield_control
    end

    it 'retreives limiters' do
      subject << unlimiter
      expect(subject.fetch(unlimiter.key)).to be unlimiter
      expect(subject.fetch(unlimiter.key, :default)).to be unlimiter
    end
  end

  describe '#include?' do
    before do
      subject << unlimiter
    end

    it 'works with keys' do
      is_expected.to include unlimiter.key
    end

    it 'works with limiters' do
      is_expected.to include unlimiter
    end

    it 'works when target is missing' do
      is_expected.not_to include inhibitor.key
      is_expected.not_to include inhibitor
    end
  end

  describe '#clear' do
    it 'works when empty' do
      subject.clear
    end

    it 'clears limiters' do
      subject << unlimiter
      is_expected.to include unlimiter

      subject.clear
      is_expected.not_to include unlimiter
    end
  end

  describe '#count' do
    it 'counts' do
      expect(subject.count).to be 0

      subject << unlimiter
      expect(subject.count).to be 1
    end
  end

  describe '#delete' do
    it 'works when the target is missing' do
      subject.delete(unlimiter)
      subject.delete(unlimiter.key)
    end

    it 'works with keys' do
      subject << unlimiter
      is_expected.to include unlimiter

      subject.delete(unlimiter.key)
      is_expected.not_to include unlimiter
    end

    it 'works with limiters' do
      subject << unlimiter
      is_expected.to include unlimiter

      subject.delete(unlimiter)
      is_expected.not_to include unlimiter
    end
  end

  describe '#empty?' do
    it 'works' do
      is_expected.to be_empty

      subject << unlimiter
      is_expected.not_to be_empty
    end
  end
end
