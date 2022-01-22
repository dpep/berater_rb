module Berater
  module Middleware
    autoload 'FailOpen', 'berater/middleware/fail_open'
    autoload 'LoadShedder', 'berater/middleware/load_shedder'
    autoload 'Statsd', 'berater/middleware/statsd'
    autoload 'Trace', 'berater/middleware/trace'
  end
end
