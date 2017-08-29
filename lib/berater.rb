module Berater
  VERSION = '0.0.1'

  class << self

    def init redis
      @@redis = redis
    end


    def incr key, limit, seconds
      ts = Time.now.to_i

      # bucket into time slot
      rkey = "%s:%s:%d" % [ self.to_s, key, ts - ts % seconds ]

      count = @@redis.multi do
        @@redis.incr rkey
        @@redis.expire rkey, seconds * 2
      end.first

      raise LimitExceeded if count > limit

      count
    end

  end

  class LimitExceeded < RuntimeError; end
end
