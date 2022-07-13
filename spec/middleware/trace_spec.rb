require 'ddtrace'

describe Berater::Middleware::Trace do
  before do
    Datadog.tracer.enabled = false
    allow(tracer).to receive(:trace).and_yield(span)
  end

  it_behaves_like 'a limiter middleware'

  let(:limiter) { Berater::Unlimiter.new }
  let(:span) { double(Datadog::Span, set_tag: nil) }
  let(:tracer) { double(Datadog::Tracer) }

  describe '#tracer' do
    subject { instance.send(:tracer) }

    let(:instance) { described_class.new }

    it 'defaults to Datadog.tracer' do
      expect(Datadog).to receive(:tracer)
      subject
    end

    context 'when provided a tracer' do
      let(:instance) { described_class.new(tracer: tracer) }

      it 'uses the tracer' do
        expect(Datadog).not_to receive(:tracer)
        is_expected.to be tracer
      end
    end
  end

  describe '#call' do
    let(:instance) { described_class.new(tracer: tracer) }

    it 'yields' do
      expect {|b| instance.call(limiter, &b) }.to yield_control
    end

    context 'when a Berater::Overloaded exception is raised' do
      it 'tags the span as overloaded and raises' do
        expect(span).to receive(:set_tag).with('overloaded', true)

        expect {
          instance.call(limiter) { raise Berater::Overloaded }
        }.to be_overloaded
      end
    end

    context 'when an exception is raised' do
      it 'tags the span and raises' do
        expect(span).to receive(:set_tag).with('error', 'IOError')

        expect {
          instance.call(limiter) { raise IOError }
        }.to raise_error(IOError)
      end
    end
  end

  context 'when used as middleware' do
    before do
      Berater.middleware.use described_class, tracer: tracer
    end

    it 'traces' do
      expect(tracer).to receive(:trace).with('Berater')
      expect(span).to receive(:set_tag).with('key', limiter.key)
      expect(span).to receive(:set_tag).with('capacity', Numeric)
      expect(span).to receive(:set_tag).with('contention', Numeric)

      limiter.limit
    end

    context 'when limiter is overloaded' do
      let(:limiter) { Berater::Inhibitor.new }

      it 'tags the span as overloaded and raises' do
        expect(span).to receive(:set_tag).with('overloaded', true)

        expect {
          limiter.limit
        }.to be_overloaded
      end
    end
  end
end
