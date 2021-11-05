require 'datadog/statsd'

describe Berater::Middleware::Statsd do
  let(:client) { double(Datadog::Statsd) }

  before do
    allow(client).to receive(:gauge)
    allow(client).to receive(:increment)
    allow(client).to receive(:timing)
  end

  describe '#call' do
    subject { described_class.new(client, **client_opts).call(limiter, **opts, &block) }

    let(:client_opts) { {} }
    let(:limiter) { double(Berater::Limiter, key: :key, capacity: 5) }
    let(:lock) { double(Berater::Lock, capacity: 4, contention: 2) }
    let(:opts) { { capacity: lock.capacity, cost: 1 } }
    let(:block) { lambda { lock } }

    after { subject }

    it 'returns a lock' do
      expect(subject).to be lock
    end

    it 'tracks the call' do
      expect(client).to receive(:timing).with(
        'berater.limiter.limit',
        Float,
        tags: {
          key: limiter.key,
          limiter: String,
          overloaded: false,
        },
      )
    end

    it 'tracks limiter capacity' do
      expect(client).to receive(:gauge).with(
        'berater.limiter.capacity',
        limiter.capacity,
        Hash
      )
    end

    context 'when custom tags are passed in' do
      let(:opts) { { tags: { abc: 123 } } }

      it 'incorporates the tags' do
        expect(client).to receive(:timing) do |*, tags:|
          expect(tags).to include(opts[:tags])
        end
      end
    end

    context 'with global tags' do
      let(:client_opts) { { tags: { abc: 123 } }}

      it 'incorporates the tags' do
        expect(client).to receive(:timing) do |*, tags:|
          expect(tags).to include(client_opts[:tags])
        end
      end
    end

    context 'with global tag callback' do
      let(:client_opts) { { tags: callback }}
      let(:callback) { double(Proc) }

      it 'calls the callback' do
        expect(callback).to receive(:call).with(limiter, **opts)
      end

      it 'incorporates the tags' do
        expect(callback).to receive(:call).and_return({ abc: 123 })

        expect(client).to receive(:timing) do |*, tags:|
          expect(tags).to include(abc: 123)
        end
      end
    end
  end

  context 'with a limiter' do
    before do
      Berater.middleware.use described_class, client
    end

    let(:limiter) { Berater::ConcurrencyLimiter.new(:key, 3) }

    it 'tracks calls to limit' do
      expect(client).to receive(:timing) do |*, tags:|
        expect(tags[:limiter]).to eq 'ConcurrencyLimiter'
      end

      expect(client).to receive(:gauge).with(
        'berater.limiter.capacity',
        limiter.capacity,
        Hash,
      )

      expect(client).to receive(:gauge).with(
        'berater.limiter.contention',
        1,
        Hash,
      )

      limiter.limit
    end

    it 'tracks each call' do
      expect(client).to receive(:gauge).with(
        'berater.limiter.contention',
        1,
        Hash,
      )

      expect(client).to receive(:gauge).with(
        'berater.limiter.contention',
        2,
        Hash,
      )

      2.times { limiter.limit }
    end

    context 'when an exception is raised' do
      before do
        expect(limiter).to receive(:redis).and_raise(error)
      end

      let(:error) { Redis::TimeoutError }

      it 'tracks limiter exceptions' do
        expect(client).to receive(:increment).with(
          'berater.limiter.error',
          tags: hash_including(type: 'Redis_TimeoutError'),
        )

        expect { limiter.limit }.to raise_error(error)
      end

      context 'with FailOpen middleware inserted after' do
        before do
          Berater.middleware.use Berater::Middleware::FailOpen
        end

        it 'does not track the exception' do
          expect(client).not_to receive(:increment).with(
            'berater.limiter.error',
          )

          limiter.limit
        end

        it 'does not track lock-based stats' do
          expect(client).not_to receive(:gauge).with(
            'berater.lock.capacity',
          )

          expect(client).not_to receive(:gauge).with(
            'berater.limiter.contention',
          )

          limiter.limit
        end
      end

      context 'with FailOpen middleware inserted before' do
        before do
          Berater.middleware.prepend Berater::Middleware::FailOpen
        end

        it 'tracks the exception' do
          expect(client).to receive(:increment).with(
            'berater.limiter.error',
            anything,
          )

          limiter.limit
        end

        it 'does not track lock-based stats' do
          expect(client).not_to receive(:gauge).with(
            'berater.lock.capacity',
          )

          expect(client).not_to receive(:gauge).with(
            'berater.limiter.contention',
          )

          limiter.limit
        end
      end
    end

    context 'when the limiter is overloaded' do
      before { limiter.capacity.times { limiter.limit } }

      after do
        expect { limiter.limit }.to be_overloaded
      end

      it 'tracks the limit call' do
        expect(client).to receive(:timing).with(
          'berater.limiter.limit',
          Float,
          tags: hash_including(overloaded: true),
        )
      end

      it 'tracks contention' do
        expect(client).not_to receive(:gauge).with(
          'berater.limiter.contention',
          limiter.capacity,
        )
      end

      it 'does not track the exception' do
        expect(client).not_to receive(:increment).with(
          'berater.limiter.error',
        )
      end
    end
  end
end
