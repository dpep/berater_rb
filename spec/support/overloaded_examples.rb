RSpec.shared_examples 'it is overloaded' do
  # subject { limiter }

  it { expect { subject }.to be_overloaded }
  it { expect { subject.limit }.to be_overloaded }
  it { expect { subject.limit }.to raise_error(Berater::Overloaded) }
  it { expect(subject).to be_overloaded }
  # it { expect(subject.overloaded?).to be true }
end

RSpec.shared_examples 'it is not overloaded' do
  # subject { limiter }

  it { expect { subject }.not_to be_overloaded }
  it { expect { subject.limit }.not_to be_overloaded }
  it { expect {|block| subject.limit(&block) }.to yield_control }
  it { expect(subject.limit).to be_a Berater::Lock }
  it { expect(subject).not_to be_overloaded }
  # it { expect(subject.overloaded?).to be false }
end
