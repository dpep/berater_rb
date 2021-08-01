describe Berater::LuaScript do
  subject { Berater::LuaScript('return redis.call("PING")') }

  before { redis.script(:flush) }

  let(:redis) { Berater.redis }

  it { is_expected.to be_a Berater::LuaScript }

  describe '#eval' do
    def ping
      expect(subject.eval(redis)).to eq 'PONG'
    end

    it { ping }

    it 'loads the script into redis' do
      expect(redis).to receive(:evalsha).once.and_call_original
      expect(redis).to receive(:eval).once.and_call_original
      ping
      expect(subject.loaded?(redis)).to be true
    end
  end

  describe '#load' do
    it 'loads script into redis' do
      expect(redis.script(:exists, subject.sha)).to be false
      subject.load(redis)
      expect(redis.script(:exists, subject.sha)).to be true
    end

    it 'returns the sha' do
      expect(subject.load(redis)).to eq subject.sha
    end

    it 'validates the returned sha' do
      allow(redis).to receive(:script).with(:flush).and_call_original
      expect(redis).to receive(:script).with(:load, String).and_return('abc')
      expect { subject.load(redis) }.to raise_error(RuntimeError)
    end
  end

  describe '#loaded?' do
    it do
      expect(subject.loaded?(redis)).to be false
      subject.load(redis)
      expect(subject.loaded?(redis)).to be true
    end
  end

  describe '#to_s' do
    it { expect(subject.to_s).to be subject.source }
  end

  describe '#minify' do
    subject do
      expect(
        Berater::LuaScript(lua).send(:minify)
      ).to eq expected
    end

    context do
      let(:lua) do <<-LUA
          -- this comment gets removed
          redis.call('PING')  -- this one too
        LUA
      end

      let(:expected) { "redis.call('PING')" }

      it { subject }
    end

    context 'with if statement' do
      let(:lua) do <<~LUA
          if condition then
            call
          end

          return 123
        LUA
      end

      let(:expected) do
        [
          'if condition then',
          'call',
          'end',
          'return 123'
        ].join "\n"
      end

      it { subject }
    end
  end
end
