Berater
======
A framework for limiting resource utilization, with build in rate and capacity limiters.  Backed by [Redis](https://redis.io/).

```ruby
require 'berater'

Berater(:key, :rate, 2, :second) do
  # do work, twice per second with a rate limiter
end


Berater(:key, :concurrency, 3) do
  # or three simultaneous request at a time, with a concurrency limiter
end
```


#### Install
```gem install berater```

## RateLimiter
A [leaky bucket](https://en.wikipedia.org/wiki/Leaky_bucket) rate limiter.

```ruby
Berater::RateLimiter.new(key, count, interval, **opts)
```
* `key` - name of limiter
* `count` - how many requests
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
Berater(:key, :rate, 2, :second) do
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
Berater(:key, :concurrency, 3) do
  ...
end
```


#### Configure
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
  let(:limiter) { Berater.new(:key, :rate, 1, :second) }
  
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
  let(:limiter) { Berater.new(:key, :rate, 1, :second) }

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
