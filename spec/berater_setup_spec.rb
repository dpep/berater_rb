describe Berater do
  it 'is connected to Redis' do
    expect(Berater.redis.ping).to eq 'PONG'
  end

  it { is_expected.to respond_to :configure }

  it 'permits redis to be reset' do
    Berater.redis = nil
    expect(Berater.redis).to be_nil
  end
end
