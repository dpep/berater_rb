Berater
======
All systems have limits, beyond which they tend to fail.  So we should strive to understand a system's limits and work within them.  Better to cause a few excessive requests to fail than bring down the whole server and deal with a chaotic, systemic failure.  Berater makes working within limits easy.


```ruby
require 'berater'
require 'redis'

Berater.configure do |c|
  c.redis = Redis.new
end

Berater(:key, 2, :second) do
  # do work, twice per second with a rate limiter
end


Berater(:key, 3) do
  # or three simultaneous request at a time, with a concurrency limiter
end
```

## Berater
```ruby
Berater(key, capacity, interval = nil, **opts, &block)
```
* `key` - name of limiter
* `capacity` - how many requests
* `interval` - how often the limit resets, if it does (either number of seconds or a symbol: `:second`, `:minute`, `hour`)
* `opts`
  * `redis` - a redis instance
* `block` - optional block to call immediately via `.limit`


## Berater::Limiter
The base class for all limiters.

```ruby
limiter = Berater(*)
limiter.limit(**opts) do
  # limited work
end

lock = limiter.limit
# do work inline
lock.release

limiter.limit(cost: 2) do
# do extra expensive work
end

limiter.limit(capacity: 3) do
# do work within the new capacity limit
end
```

`.limit` - acquire a lock.  Raises a `Berater::Overloaded` error if limits have been exceeded.  When passed a block, it will execute the block unless the limit has been exceeded.  Otherwise it returns the lock, which should be released once completed.
* `capacity` - override the limiter's capacity for this call
* `cost` - the relative cost of this piece of work, default is 1


### Berater::Lock
Created when a call to `.limit` is successful.

```ruby
Berater(*) do |lock|
  lock.contention
end

# or inline
lock = Berater(*).limit
```

* `.contention` - capacity currently being used
* `.locked?` - whether the lock is currently being held
* `.release` - release capacity being held


## Berater::RateLimiter
A [leaky bucket](https://en.wikipedia.org/wiki/Leaky_bucket) rate limiter.  Useful when you want to limit usage within a given time window, eg. 2 times per second.

```ruby
Berater::RateLimiter.new(key, capacity, interval, **opts)
```
* `key` - name of limiter
* `capacity` - how many requests
* `interval` - how often, ie. how much time it takes for the limit to reset.  Either number of seconds or a symbol: `:second`, `:minute`, `hour`
* `opts`
  * `redis` - a redis instance

eg.
```ruby
limiter = Berater::RateLimiter.new(:key, 2, :second, redis: redis)
limiter.limit do
  # do work, twice per second with a rate limiter
end

# or, more conveniently
Berater(:key, 2, :second) do
  ...
end
```


## Berater::ConcurrencyLimiter
Useful to limit the amount of work done concurrently, ie. simulteneously.  eg. no more than 3 connections at once.

```ruby
Berater::ConcurrencyLimiter.new(key, capacity, **opts)
```
* `key` - name of limiter
* `capacity` - maximum simultaneous requests
* `opts`
  * `timeout` - maximum seconds a lock may be held (optional, but recommended)
  * `redis` - a redis instance

eg.
```ruby
limiter = Berater::ConcurrencyLimiter.new(:key, 3, redis: redis)
limiter.limit do
  # do work, three simultaneous requests at a time
end

# or, more conveniently
Berater(:key, 3) do
  ...
end
```



## Install
```gem install berater```

Configure a default redis connection.

```ruby
Berater.configure do |c|
  c.redis = Redis.new
end
```


## Integrations

### Rails
Convert limit errors into a HTTP [status code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429)

```ruby
class ApplicationController < ActionController::Base
  rescue_from Berater::Overloaded do
    head :too_many_requests
  end
end
```

### Sidekiq
Ensure Berater plays nice with [Sidekiq Ent](https://github.com/mperham/sidekiq/wiki/Ent-Rate-Limiting#custom-errors)

```ruby
Sidekiq::Limiter.errors << Berater::Overloaded
```


## Testing
Berater has a few tools to make testing easier.  And it plays nicely with [Timecop](https://github.com/travisjeffery/timecop).


### test_mode
Force all `limit` calls to either pass or fail, without hitting Redis.

```ruby
require 'berater/test_mode'

describe 'MyTest' do
  let(:limiter) { Berater.new(:key, 1, :second) }
  
  context 'with test_mode = :pass' do
    before { Berater.test_mode = :pass }

    it 'always works' do
      10.times { limiter.limit { ... } }
    end
  end

  context 'with test_mode = :fail' do
    before { Berater.test_mode = :fail }

    it 'always raises an exception' do
      expect { limiter.limit }.to raise_error(Berater::Overloaded)
    end
  end
end
```


### rspec
rspec matchers and automatic flushing of Redis between examples.

```ruby
require 'berater/rspec'

describe 'MyTest' do
  let(:limiter) { Berater.new(:key, 1, :second) }

  it 'rate limits' do
    limiter.limit
    
    expect { limiter.limit }.to be_overloaded
  end
end
```

### Unlimiter
A limiter which always succeeds.

```ruby
limiter = Berater::Unlimiter.new
```

### Inhibitor
A limiter which always fails.

```ruby
limiter = Berater::Inhibitor.new
```

----
## Misc

### A riddle!

What's the difference between a rate limiter and a concurrency limiter?  Can you build one with the other?

Both enforce limits, but differ with respect to time and memory.  A rate limiter can be implemented using a concurrency limiter, by allowing every lock to timeout.  A concurrency limiter can nearly be implemented using a rate limiter, by decrementing the used capacity when a lock is released.  The order of locks, however, is lost and thus a timeout will not properly function.

An [example](https://github.com/dpep/berater_rb/blob/master/spec/riddle_spec.rb) is worth a thousand words  :)


### DSL
Experimental...

```ruby
using Berater::DSL

Berater(:key) { 1.per second } do
  ...
end

Berater(:key) { 3.at_once } do
  ...
end

```


### Load Shedding
If work has different priorities, then preemptively shedding load will facilitate more graceful failures.  Low priority work should yield to higher priorty work.  Here's a simple, yet effective approach:

```ruby
limiter = Berater(*)

capacity = if priority == :low
  (limiter.capacity * 0.8).to_i
end

limiter.limit(capacity: capacity) do
  # work
end 

```


----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`bundle exec rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push your branch (`git push origin my-feature`)
1. Create a Pull Request


----
![Gem](https://img.shields.io/gem/dt/berater?style=plastic)
[![codecov](https://codecov.io/gh/dpep/berater_rb/branch/master/graph/badge.svg?token=1L7OD80182)](https://codecov.io/gh/dpep/berater_rb)
