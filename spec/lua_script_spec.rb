describe Berater::LuaScript do
  subject { Berater::LuaScript('return redis.call("PING")') }

  before { redis.script('FLUSH') }

  let(:redis) { Berater.redis }

  it { is_expected.to be_a Berater::LuaScript }

  describe '#load' do
    it 'loads script into redis' do
      expect(redis.script('EXISTS', subject.sha)).to be false
      subject.load(redis)
      expect(redis.script('EXISTS', subject.sha)).to be true
    end

    it 'returns the sha' do
      expect(subject.load(redis)).to eq subject.sha
    end

    it 'validates the returned sha' do
      allow(redis).to receive(:script).with(:flush).and_call_original
      expect(redis).to receive(:script).with('LOAD', String).and_return('abc')
      expect { subject.load(redis) }.to raise_error(RuntimeError)
    end
  end

  describe '#eval' do
    def ping
      expect(subject.eval(redis)).to eq 'PONG'
    end

    it 'works' do
      ping
    end

    it 'loads the script into redis' do
      expect(subject).to receive(:load).and_call_original
      ping
    end

    it 'falls back to eval' do
      expect(redis).to receive(:evalsha).twice.and_call_original
      expect(subject).to receive(:load).once # skip load
      expect(redis).to receive(:eval).once.and_call_original
      ping
    end

    it 'does not suppress load errors' do
      expect(subject).to receive(:load).and_raise(Redis::CommandError)

      expect { ping }.to raise_error(Redis::CommandError)
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
        LUA
      end

      let(:expected) do
        [
          'if condition then',
          'call',
          'end',
        ].join "\n"
      end

      it { subject }
    end
  end

end
