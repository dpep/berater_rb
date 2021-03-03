require 'sidekiq'

begin
  require 'sidekiq-ent'
rescue LoadError; end

if defined?(Sidekiq::Limiter)
  # https://github.com/mperham/sidekiq/wiki/Ent-Rate-Limiting#custom-errors
  Sidekiq::Limiter.errors << Berater::Overloaded
end
