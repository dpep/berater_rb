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


Berater(:key, :rate, 2, :second) do
  # do work, twice per second with a rate limiter
end


Berater(:key, :concurrency, 1) do
  # or one at a time with a concurrency limiter
end

```


#### rspec
Berater has a few tools to make testing easier.  rspec matchers, automatic flushing of Redis between examples, and a test mode to force your desired behavior and avoid redis altogether.  The [Timecop](https://github.com/travisjeffery/timecop) gem is recommended.

```ruby
require 'berater/rspec'
require 'berater/test_mode'

describe 'MyWorker' do
  let(:limiter) { Berater.new(:key, :rate, 1, :second) }

  it 'rate limits' do
    limiter.limit { ... }

    expect { limiter.limit }.to raise_error(Berater::Overloaded)

    # or use a matcher
    expect { limiter.limit }.to be_overloaded
  end

  context 'with test_mode = :pass' do
    before { Berater.test_mode = :pass }

    it 'always works' do
      10.times { limiter.limit { ... } }
    end
  end

  context 'with test_mode = :fail' do
    before { Berater.test_mode = :fail }

    it 'always raises an exception' do
      expect { limiter.limit }.to be_overloaded
    end
  end
end
```

#### DSL
```ruby

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
