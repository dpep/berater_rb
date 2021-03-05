describe Berater::Limiter do

  it 'can not be initialized' do
    expect { described_class.new }.to raise_error(NotImplementedError)
  end

end
