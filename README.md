Berater
======
Limiting resource utilization.  Backed by [Redis](https://redis.io/).


```ruby
require 'berater'

Berater(:key, 2, :second) do
  # do work, twice per second with a rate limiter
end


Berater(:key, 3) do
  # or three simultaneous request at a time, with a concurrency limiter
end
```

```ruby
Berater(key, capacity, interval = nil, **opts, &block)
```
Do something...within limits
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
# do some work inline
lock.release
```

`.limit` - acquire a lock.  Raises a `Berater::Overloaded` error if limits have been exceeded.  When passed a block, it will execute the block unless the limit has been exceeded.  Otherwise it returns the lock, which should be released once completed.
* `capacity` - override the limiter's capacity for this call
* `cost` - the relative cost of this piece of work, default is 1


#### Berater::Lock
Created when a call to `.limit` is successful, it also contains some useful information

```ruby
Berater(*) do |lock|
  lock.contention
end

# or inline
lock = Berater(*).limit
```

* `.contention` - capacity currently being used
* `.locked` - whether the lock is currently being held
* `.release` - release capacity being held


## RateLimiter
A [leaky bucket](https://en.wikipedia.org/wiki/Leaky_bucket) rate limiter.

```ruby
Berater::RateLimiter.new(key, capacity, interval, **opts)
```
* `key` - name of limiter
* `capacity` - how many requests
* `interval` - how often (either number of seconds or a symbol: `:second`, `:minute`, `hour`)
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


## ConcurrencyLimiter
```ruby
Berater::ConcurrencyLimiter.new(key, capacity, **opts)
```
* `key` - name of limiter
* `capacity` - maximum simultaneous requests
* `opts`
  * `redis` - a redis instance
  * `timeout` - maximum seconds a request may take before lock is released

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

#### Rails
Convert limit errors into a HTTP [status code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429)

```ruby
class ApplicationController < ActionController::Base
  rescue_from Berater::Overloaded do
    head :too_many_requests
  end
end
```

#### Sidekiq
Ensure Berater plays nice with [Sidekiq Ent](https://github.com/mperham/sidekiq/wiki/Ent-Rate-Limiting#custom-errors)

```ruby
Sidekiq::Limiter.errors << Berater::Overloaded
```


## Testing
Berater has a few tools to make testing easier.  And it plays nicely with [Timecop](https://github.com/travisjeffery/timecop).


#### test_mode
Force all calls to `limit` to either pass or fail, without hitting Redis.

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


#### rspec
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

#### Unlimiter
A limiter which always succeeds.

```ruby
limiter = Berater::Unlimiter.new
```

#### Inhibitor
A limiter which always fails.

```ruby
limiter = Berater::Inhibitor.new
```

----
#### DSL
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
