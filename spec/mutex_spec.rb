describe Berater::Mutex do
  let(:klass) do
    Class.new do
      include Berater::Mutex
    end
  end

  describe 'synchronize' do
    it { expect(klass).to respond_to(:synchronize) }
    it { expect(klass.new).to respond_to(:synchronize) }

    it { expect { |block| klass.synchronize(&block) }.to yield_control }

    it 'returns the blocks value' do
      res = klass.synchronize { 123 }
      expect(res).to be 123
    end

    it 'still works and returns nil without a block' do
      expect(klass.synchronize).to be nil
    end

    it 'does not allow simultaneous calls' do
      expect {
        klass.synchronize do
          klass.synchronize
        end
      }.to be_overloaded
    end

    it 'allows simultaneous calls with different sub-keys' do
      expect {
        klass.synchronize(:a) do
          klass.synchronize(:b)
        end
      }.not_to raise_error
    end

    it 'allows consecutive calls' do
      expect {
        3.times { klass.synchronize }
      }.not_to raise_error
    end

    describe 'the instance method' do
      it 'is a pass through to the class method' do
        expect(klass).to receive(:synchronize)
        klass.new.synchronize
      end

      it 'works with arguments' do
        key = 'key'
        opts = { timeout: 1 }
        block = ->{}

        expect(klass).to receive(:synchronize) do |this_key, **these_opts, &this_block|
          expect(this_key).to be key
          expect(these_opts).to eq opts
          expect(this_block).to be block
        end

        klass.new.synchronize(key, **opts, &block)
      end
    end
  end

  describe '.mutex_options' do
    subject { klass.mutex_options }

    it { expect(klass).to respond_to(:mutex_options) }
    it { is_expected.to be_a Hash }
    it { is_expected.to be_empty }
    it { expect(klass.new).not_to respond_to(:mutex_options) }

    context 'when mutex_options are set' do
      let(:klass) do
        Class.new do
          include Berater::Mutex

          mutex_options timeout: 1
        end
      end

      it { is_expected.to eq(timeout: 1) }

      it 'uses mutex_options during synchronize' do
        expect(Berater::ConcurrencyLimiter).to receive(:new).and_wrap_original do |original, *args, **kwargs|
          expect(kwargs).to eq(subject)
          original.call(*args, **kwargs)
        end

        klass.synchronize
      end
    end
  end

  describe 'when extended rather than included' do
    let(:klass) do
      Class.new do
        extend Berater::Mutex
      end
    end

    it { expect(klass).to respond_to(:synchronize) }
    it { expect(klass).to respond_to(:mutex_options) }

    it { expect(klass.new).not_to respond_to(:synchronize) }
    it { expect(klass.new).not_to respond_to(:mutex_options) }
  end

  describe 'when used in a counter' do
    subject(:counter) { klass.new }

    let(:klass) do
      class Counter
        include Berater::Mutex

        @@count = 0
        @@counts = {}

        def incr
          synchronize { @@count += 1 }
        end

        def incr_key(key)
          synchronize(key) do
            @@counts[key] ||= 0
            @@counts[key] += 1
          end
        end
      end
      Counter
    end

    it { expect(counter.incr).to eq 1 }
    it { expect(counter.incr_key(:a)).to eq 1 }

    it 'separates keys' do
      res = 3.times.map { counter.incr_key(:a) }
      expect(res).to eq [ 1, 2, 3 ]

      expect(counter.incr_key(:b)).to eq 1
    end
  end
end
