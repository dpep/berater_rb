shared_examples 'a limiter middleware' do
  context 'with middleware installed' do
    let(:instance) { described_class.new }

    before { Berater.middleware.use(instance) }

    it 'calls the middleware' do
      expect(instance).to receive(:call)

      Berater::Unlimiter.new.limit
    end

    it_behaves_like 'a limiter', Berater::Unlimiter.new
  end
end
