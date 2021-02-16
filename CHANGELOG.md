###  v0.2.0  (2021-02-15)
- locks for all limiters
- clean up lock
- convenience method for limiting
- simplify!  remove all .limit options in favor of initializing with everything
- simplify concurrency script
- reduce method accessibility
- remove .limit class method to simplify
- remove Berater.mode in favor of explicit instantiation

###  v0.1.4  (2021-02-08)
- handle capacity 0 properly
- cleanup tests
- refine concurrency lock

###  v0.1.3  (2021-02-05)
- bug fix.  sleep no longer needed

###  v0.1.2  (2021-02-04)
- redis determinism
- EditorConfig ftw
- move Overloaded exception into base class to clean up naming etc

###  v0.1.1  (2021-02-04)
- add lock contention stat and yield to limited block

###  v0.1.0  (2021-02-03)
- add Inhibitor / :inhibited mode for testing purposes
- change limiter loading to make more flexible
- s/Berater.limiter/Berater.new/
- upgrade concurrency lock
- test timeouts
- s/token/lock/
- can now provide "key" while calling .limit, better support for passing in options anywhere and everywhere, default key and redis values, BaseLimiter.limit class method, more test coverage
- rename spec file so it runs properly
- improve rspec matchers to use blocks and hence release tokens
- rspec matcher handles blocks and limiters
- rspec matchers ftw
- s/LimitExceeded/Overloaded/
- test with multiple keys
- namespace all keys and add expunge helper
- consolidate Berater module testing
- fix ttl 0 to indicate no expiration.  add token/release mechanism
- ConcurrencyLimiter and support for yielding
- friendly exceptions
- major overhaul.  add support for multiple limiter types, lots of test coverage
- expand configure method, add tests
- rename repo
- simplecov and codecov
- ci (#1)

