require 'openssl'

module Berater
  class LuaScript

    attr_reader :source

    def initialize(source)
      @source = source
    end

    def sha
      @sha ||= OpenSSL::Digest::SHA1.hexdigest(minify)
    end

    def load(redis)
      redis.script('LOAD', minify).tap do |sha|
        unless sha == self.sha
          raise "unexpected script SHA: expected #{self.sha}, got #{sha}"
        end
      end
    end

    def eval(redis, *args)
      retried = false

      begin
        redis.evalsha(sha, *args)
      rescue Redis::CommandError => e
        raise unless e.message.include?('NOSCRIPT')

        if retried
          # fall back to regular eval
          redis.eval(source, *args)
        else
          # load script into redis and try again
          load(redis)
          retried = true
          retry
        end
      end
    end

    def to_s
      source
    end

    private

    def minify
      # trim comments (whole line and partial)
      # and whitespace (prefix, suffix, and empty lines)
      @minify ||= source.gsub(/^\s*--.*\n|\s*--.*|^\s*|\s*$|^$\n/, '')
    end

  end

  def LuaScript(source)
    LuaScript.new(source)
  end
end
