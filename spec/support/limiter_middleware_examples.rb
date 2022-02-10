shared_examples 'a limiter middleware' do
  context 'with middleware installed' do
    before do
      unless Berater.middleware.include?(described_class)
        Berater.middleware.use(described_class)
      end
    end

    it 'calls the middleware' do
      expect_any_instance_of(described_class).to receive(:call)

      Berater::Unlimiter.new.limit
    end

    it_behaves_like 'a limiter', Berater::Unlimiter.new
  end
end
