Berater
======
![Gem](https://img.shields.io/gem/dt/berater?style=plastic)
[![codecov](https://codecov.io/gh/dpep/berater_rb/branch/main/graph/badge.svg?token=1L7OD80182)](https://codecov.io/gh/dpep/berater_rb)


All systems have limits, beyond which they tend to fail.  Berater makes working within limits easy and the inevitable failures more graceful.


```ruby
require 'berater'
require 'redis'

Berater.configure do |c|
  c.redis = Redis.new
end

Berater(:key, 3) do
  # allow only three simultaneous requests at a time, with a concurrency limiter
end

Berater(:key, 2, interval: 60) do
  # or do work twice per minute with a rate limiter
end
```

See [documentation](https://github.com/dpep/berater_rb/wiki) for details.


----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`bundle exec rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push your branch (`git push origin my-feature`)
1. Create a pull request


----
### Inspired by

https://stripe.com/blog/rate-limiters

https://github.blog/2021-04-05-how-we-scaled-github-api-sharded-replicated-rate-limiter-redis

[@ptarjan](https://gist.github.com/ptarjan/e38f45f2dfe601419ca3af937fff574d)

https://en.wikipedia.org/wiki/Leaky_bucket
