describe Berater::Matchers::Overloaded do

  context 'Berater::Unlimiter' do
    let(:limiter) { Berater::Unlimiter.new }

    it { expect(limiter).not_to be_overloaded }
    it { expect { limiter }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overloaded }
  end

  context 'Berater::Inhibitor' do
    let(:limiter) { Berater::Inhibitor.new }

    it { expect(limiter).to be_overloaded }
    it { expect { limiter }.to be_overloaded }
    it { expect { limiter.limit }.to be_overloaded }
  end

  context 'Berater::RateLimiter' do
    let(:limiter) { Berater::RateLimiter.new(:key, 1, :second) }

    it { expect(limiter).not_to be_overloaded }
    it { expect { limiter }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overloaded }

    context 'once limit is used up' do
      before { limiter.limit }

      it 'should be_overloaded' do
        expect(limiter).to be_overloaded
      end

      it 'should be_overloaded' do
        expect { limiter }.to be_overloaded
      end

      it 'should be_overloaded' do
        expect { limiter.limit }.to be_overloaded
      end
    end
  end

  context 'Berater::ConcurrencyLimiter' do
    let(:limiter) { Berater::ConcurrencyLimiter.new(:key, 1) }

    it { expect(limiter).not_to be_overloaded }
    it { expect { limiter }.not_to be_overloaded }
    it { expect { limiter.limit }.not_to be_overloaded }

    context 'when lock is released' do
      it 'should be_overloaded' do
        3.times do
          expect(limiter).not_to be_overloaded
        end
      end

      it 'should be_overloaded' do
        3.times do
          expect { limiter }.not_to be_overloaded
        end
      end

      it 'should be_overloaded' do
        3.times do
          expect { limiter.limit {} }.not_to be_overloaded
        end
      end
    end

    context 'when lock is *not* released' do
      it 'should be_overloaded' do
        expect { limiter.limit }.not_to be_overloaded
        expect { limiter.limit }.to be_overloaded
      end

      it 'should be_overloaded' do
        expect { 3.times { limiter.limit } }.to be_overloaded
      end
    end
  end

  context 'when matchers fail' do
    let(:unlimiter) { Berater::Unlimiter.new }
    let(:inhibitor) { Berater::Inhibitor.new }

    it 'catches false negatives' do
      expect {
        expect(unlimiter).to be_overloaded
      }.to fail_including('expected to be overloaded')

      expect {
        expect { unlimiter }.to be_overloaded
      }.to fail_including('expected to be overloaded')

      expect {
        expect { unlimiter.limit }.to be_overloaded
      }.to fail_including("expected #{Berater::Overloaded} to be raised")

      expect {
        expect { 123 }.to be_overloaded
      }.to fail_including("expected #{Berater::Overloaded} to be raised")
    end

    it 'catches false positives' do
      expect {
        expect(inhibitor).not_to be_overloaded
      }.to fail_including('expected not to be overloaded')

      expect {
        expect { inhibitor }.not_to be_overloaded
      }.to fail_including('expected not to be overloaded')

      expect {
        expect { inhibitor.limit }.not_to be_overloaded
      }.to fail_including("did not expect #{Berater::Overloaded} to be raised")

      expect {
        expect { raise Berater::Overloaded }.not_to be_overloaded
      }.to fail_including("did not expect #{Berater::Overloaded} to be raised")
    end
  end
end
