require 'clockwork'
require 'berater'
require 'minitest/autorun'
require 'redis'


class BeraterTest < Minitest::Test

  def test_all
    redis = Redis.new
    Berater.init redis
    key = self.to_s

    # make sure Redis is running
    assert_nil redis.get(key)

    assert_equal(
      Berater.incr(key, 2, 1.day),
      1
    )

    assert_equal(
      Berater.incr(key, 2, 1.day),
      2
    )

    assert_raises Berater::LimitExceeded do
      Berater.incr(key, 2, 1.day)
    end
  end

end
