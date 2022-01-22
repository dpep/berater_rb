describe Berater::Middleware::Trace do
  before { Datadog.tracer.enabled = false }

  it_behaves_like 'a limiter middleware'

  let(:limiter) { Berater::Unlimiter.new }
  let(:span) { double(Datadog::Span, set_tag: nil) }
  let(:tracer) { double(Datadog::Tracer) }

  before do
    allow(tracer).to receive(:trace) {|&b| b.call(span) }
  end

  context 'with a provided tracer' do
    let(:instance) { described_class.new(tracer: tracer) }

    it 'traces' do
      expect(tracer).to receive(:trace).with(/Berater/)
      expect(span).to receive(:set_tag).with(/capacity/, Numeric)

      instance.call(limiter) {}
    end

    it 'yields' do
      expect {|b| instance.call(limiter, &b) }.to yield_control
    end

    context 'when an exception is raised' do
      it 'tags the span and raises' do
        expect(span).to receive(:set_tag).with('error', 'IOError')

        expect {
          instance.call(limiter) { raise IOError }
        }.to raise_error(IOError)
      end
    end

    context 'when an Overloaded exception is raised' do
      let(:limiter) { Berater::Inhibitor.new }

      it 'tags the span as overloaded and raises' do
        expect(span).to receive(:set_tag).with('overloaded', true)

        expect {
          instance.call(limiter) { raise Berater::Overloaded }
        }.to be_overloaded
      end
    end
  end

  context 'with the default tracer' do
    it 'uses Datadog.tracer' do
      expect(Datadog).to receive(:tracer).and_return(tracer)

      described_class.new.call(limiter) {}
    end
  end
end
