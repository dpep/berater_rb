describe Berater::Inhibitor do
  subject { described_class.new }

  describe '.new' do
    it 'initializes without any arguments or options' do
      is_expected.to be_a described_class
    end

    it 'initializes with any arguments and options' do
      expect(described_class.new(:abc, :def, x: 123)).to be_a described_class
    end

    it 'has default values' do
      expect(subject.key).to be :inhibitor
      expect(subject.redis).to be Berater.redis
    end
  end

  describe '#limit' do
    it_behaves_like 'it is overloaded'
  end

  describe '#to_s' do
    it do
      expect(subject.to_s).to include described_class.to_s
    end
  end
end
