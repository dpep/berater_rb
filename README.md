Berater
======
A framework for limiting resource utilization, with build in rate and capacity limiters.  Backed by [Redis](https://redis.io/).


#### Install
```gem install berater```


#### Usage
```ruby
require 'berater'
require 'redis'

Berater.configure do |c|
  c.redis = Redis.new
end


# RateLimiter

Berater(:key, :rate, 2, :second) do |lock|
  # do work while holding a lock
end


## instantiation mode
limiter = Berater.new(:key, :rate, 2, :second)

limiter.limit do |lock|
  # do the thing
end

limiter.limit do
  # do another thing
end

begin
  limiter.limit { puts "can't do this thing yet" }
rescue Berater::Overloaded
  # it explodes
end


# Concurrency

Berater(:key, :concurrency, 1) do |lock|
  # do work while holding a lock
end


## instantiation mode

limiter = Berater.new(:key, :concurrency, 1)

3.times do
  limiter.limit { puts 'do work serially' }
end

lock = limiter.limit
# hold lock without a block

# if more work is attempted...
begin
  limiter.limit { "won't work" }
rescue Berater::Overloaded
  # it will explode
end

# release the lock when the work is done
lock.release

```

----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push to the branch (`git push origin my-feature`)
1. Create new Pull Request


----
![Gem](https://img.shields.io/gem/dt/berater?style=plastic)
[![codecov](https://codecov.io/gh/dpep/berater_rb/branch/master/graph/badge.svg?token=1L7OD80182)](https://codecov.io/gh/dpep/berater_rb)
