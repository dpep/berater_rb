require 'berater/version'


module Berater
  extend self

  class LimitExceeded < RuntimeError; end

  attr_accessor :redis

  def configure redis
    self.redis = redis
  end

  def incr key, limit, seconds
    ts = Time.now.to_i

    # bucket into time slot
    rkey = "%s:%s:%d" % [ self.to_s, key, ts - ts % seconds ]

    count, _ = redis.multi do
      redis.incr rkey
      redis.expire rkey, seconds * 2
    end

    raise LimitExceeded if count > limit

    count
  end
end
