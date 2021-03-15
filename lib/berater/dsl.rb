module Berater
  module DSL
    refine Berater.singleton_class do
      def new(key, capacity = nil, **opts, &block)
        if capacity.nil?
          unless block_given?
            raise ArgumentError, 'expected either capacity or block'
          end

          capacity, more_opts = DSL.eval(&block)
          opts.merge!(more_opts) if more_opts
        else
          if block_given?
            raise ArgumentError, 'expected either capacity or block, not both'
          end
        end

        super(key, capacity, **opts)
      end
    end

    extend self

    def eval &block
      @keywords ||= Class.new do
        # create a class where DSL keywords are methods
        KEYWORDS.each do |keyword|
          define_singleton_method(keyword) { keyword }
        end
      end

      install
      @keywords.class_eval &block
    ensure
      uninstall
    end

    private

    KEYWORDS = [
      :second, :minute, :hour,
    ].freeze

    def install
      Integer.class_eval do
        def per(unit)
          [ self, interval: unit ]
        end
        alias every per

        def at_once
          [ self ]
        end
        alias concurrently at_once
        alias at_a_time at_once
      end
    end

    def uninstall
      Integer.remove_method :per
      Integer.remove_method :every

      Integer.remove_method :at_once
      Integer.remove_method :concurrently
      Integer.remove_method :at_a_time
    end
  end
end
