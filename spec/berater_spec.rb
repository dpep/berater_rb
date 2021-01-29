describe Berater do
  def incr
    Berater.incr 'key', 5, 1
  end

  it 'counts' do
    expect(incr).to eq 1
  end

  it 'counts many times' do
    5.times do |i|
      expect(incr).to eq (i + 1) # i is 0-offset
    end
  end

  it 'limits excessive calls' do
    5.times do |i|
      expect(incr).to eq (i + 1) # i is 0-offset
    end

    expect { incr }.to raise_error(Berater::LimitExceeded)
  end

  it 'works with symbols' do
    count = Berater.incr :key, 5, 1
    expect(count).to eq 1
  end
end
