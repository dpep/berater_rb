Berater
======
A simple rate limiter, backed by Redis


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
limiter = Berater::RateLimiter.new(2, :second)

limiter.limit do
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
limiter = Berater::ConcurrencyLimiter.new(1)

3.times do
  limiter.limit { puts 'do work serially' }
end

lock = limiter.limit
# do work while holding the lock

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
![Gem](https://img.shields.io/gem/dt/berater?style=plastic)
[![codecov](https://codecov.io/gh/dpep/berater_rb/branch/master/graph/badge.svg?token=1L7OD80182)](https://codecov.io/gh/dpep/berater_rb)
