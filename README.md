Berater
======
A simple rate limiter, backed by Redis


#### Install
```gem install berater```


#### Usage
```
require 'berater'
require 'redis'

Berater.init Redis.new

begin
  5.times do
    puts Berater.incr 'hi', 2, 10
  end
rescue Berater::LimitExceeded; end

```
