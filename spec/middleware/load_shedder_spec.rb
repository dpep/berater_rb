describe Berater::Middleware::LoadShedder do
  it_behaves_like 'a limiter middleware'

  describe '#call' do
    subject { described_class.new }

    it 'yields' do
      expect {|b| subject.call(&b) }.to yield_control
    end

    it 'passes through capacity and cost options' do
      opts = {
        capacity: 1,
        cost: 2,
      }

      subject.call(**opts) do |**passed_opts|
        expect(passed_opts).to eq(opts)
      end
    end

    it 'strips out priority from options' do
      opts = {
        capacity: 1,
        priority: 3,
      }

      subject.call(**opts) do |**passed_opts|
        expect(passed_opts.keys).not_to include(:priority)
      end
    end

    it 'keeps full capacity for priority 1' do
      subject.call(capacity: 100, priority: 1) do |capacity:|
        expect(capacity).to eq 100
      end
    end

    it 'adjusts the capactiy according to priority' do
      subject.call(capacity: 100, priority: 2) do |capacity:|
        expect(capacity).to be < 100
      end

      subject.call(capacity: 100, priority: 5) do |capacity:|
        expect(capacity).to eq 60
      end
    end

    it 'works with a fractional priority' do
      subject.call(capacity: 100, priority: 1.5) do |capacity:|
        expect(capacity).to be < 100
      end
    end

    context 'with a default priority' do
      subject { described_class.new(default_priority: 5) }

      it 'keeps full capacity for priority 1' do
        subject.call(capacity: 100, priority: 1) do |capacity:|
          expect(capacity).to eq 100
        end
      end

      it 'uses the default priority' do
        subject.call(capacity: 100) do |capacity:|
          expect(capacity).to eq 60
        end
      end
    end

    context 'with a stringified priority' do
      it 'casts the value' do
        subject.call(capacity: 100, priority: '5') do |capacity:|
          expect(capacity).to eq 60
        end
      end
    end

    context 'with a bogus priority value' do
      it 'ignores the priority option' do
        subject.call(capacity: 100, priority: nil) do |capacity:|
          expect(capacity).to eq 100
        end

        subject.call(capacity: 100, priority: -1) do |capacity:|
          expect(capacity).to eq 100
        end

        subject.call(capacity: 100, priority: 0) do |capacity:|
          expect(capacity).to eq 100
        end

        subject.call(capacity: 100, priority: 50) do |capacity:|
          expect(capacity).to eq 100
        end

        subject.call(capacity: 100, priority: 'abc') do |capacity:|
          expect(capacity).to eq 100
        end

        subject.call(capacity: 100, priority: :abc) do |capacity:|
          expect(capacity).to eq 100
        end
      end
    end
  end

  context 'with a limiter' do
    before do
      Berater.middleware.use Berater::Middleware::LoadShedder
    end

    shared_examples 'limiter load shedding' do |limiter|
      it 'passes through the capactiy properly' do
        expect(limiter).to receive(:inner_limit).with(
          hash_including(capacity: 100)
        ).and_call_original

        limiter.limit
      end

      it 'scales the capactiy with priority' do
        expect(limiter).to receive(:inner_limit).with(
          hash_including(capacity: 60)
        ).and_call_original

        limiter.limit(priority: 5)
      end

      it 'overloads properly' do
        60.times { limiter.limit(priority: 5) }

        expect {
          limiter.limit(priority: 5)
        }.to be_overloaded

        expect {
          limiter.limit(priority: 4)
        }.not_to be_overloaded

        39.times { limiter.limit(priority: 1) }

        expect {
          limiter.limit(priority: 1)
        }.to be_overloaded
      end
    end

    include_examples 'limiter load shedding', Berater::ConcurrencyLimiter.new(:key, 100)
    include_examples 'limiter load shedding', Berater::RateLimiter.new(:key, 100, :second)
  end
end
