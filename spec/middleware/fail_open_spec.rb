describe Berater::Middleware::FailOpen do
  let(:limiter) { Berater::Unlimiter.new }
  let(:lock) { limiter.limit }
  let(:error) { Redis::TimeoutError }

  describe '.call' do
    let(:instance) { described_class.new(on_fail: on_fail) }
    let(:on_fail) { nil }

    it 'returns the blocks value' do
      expect(instance.call { lock }).to be lock
    end

    context 'when Redis times out during lock acquisition' do
      subject { instance.call { raise error } }

      it 'still returns a lock' do
        expect(subject).to be_a Berater::Lock
      end

      it 'creates a new, fake lock' do
        expect(Berater::Lock).to receive(:new)
        subject
      end

      it 'returns a lock that is releasable' do
        expect(subject.release).to be true
      end

      context 'when an on_fail handler is defined' do
        let(:on_fail) { double(Proc) }

        it 'calls the handler' do
          expect(on_fail).to receive(:call).with(error)
          subject
        end
      end
    end

    context 'when Redis times out during lock release' do
      subject { instance.call { lock }.release }

      before do
        expect(lock).to receive(:release).and_raise(error)
      end

      it 'handles the exception' do
        expect { subject }.not_to raise_error
      end

      it 'returns false since lock was not released' do
        is_expected.to be false
      end

      context 'when an on_fail handler is defined' do
        let(:on_fail) { double(Proc) }

        it 'calls the handler' do
          expect(on_fail).to receive(:call).with(Exception)
          subject
        end
      end
    end
  end

  context 'when Redis times out during lock acquisition' do
    before do
      expect(limiter).to receive(:acquire_lock).and_raise(error)
    end

    it 'raises an exception for the caller' do
      expect { limiter.limit }.to raise_error(error)
    end

    context 'when FailOpen middleware is enabled' do
      before do
        Berater.middleware.use described_class
      end

      it 'fails open' do
        expect(limiter.limit).to be_a Berater::Lock
      end

      it 'returns the intended result' do
        expect(limiter.limit { 123 }).to be 123
      end
    end

    context 'when FailOpen middleware is enabled with callback' do
      before do
        Berater.middleware.use described_class, on_fail: on_fail
      end
      let(:on_fail) { double(Proc) }

      it 'calls the callback' do
        expect(on_fail).to receive(:call).with(Exception)
        limiter.limit
      end
    end
  end

  context 'when Redis times out during lock release' do
    before do
      allow(limiter).to receive(:acquire_lock).and_return(lock)
      allow(lock).to receive(:release).and_raise(error)
    end

    it 'acquires a lock' do
      expect(limiter.limit).to be_a Berater::Lock
      expect(limiter.limit).to be lock
    end

    it 'raises an exception when lock is released' do
      expect {
        limiter.limit.release
      }.to raise_error(error)
    end

    it 'raises an exception when lock is auto released' do
      expect {
        limiter.limit {}
      }.to raise_error(error)
    end

    context 'when FailOpen middleware is enabled' do
      before do
        Berater.middleware.use described_class
      end

      it 'fails open' do
        expect { limiter.limit.release }.not_to raise_error
      end

      it 'returns the intended result' do
        expect(limiter.limit { 123 }).to be 123
      end
    end

    context 'when FailOpen middleware is enabled with callback' do
      before do
        Berater.middleware.use described_class, on_fail: on_fail
      end
      let(:on_fail) { double(Proc) }

      it 'calls the callback' do
        expect(on_fail).to receive(:call).with(Exception)
        limiter.limit {}
      end
    end
  end
end
