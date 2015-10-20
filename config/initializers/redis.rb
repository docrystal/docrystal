module Docrystal
  def redis
    RequestStore.fetch(:redis) do
      redis_url = ENV['REDIS_URL'] || ENV['REDISCLOUD_URL'] || nil
      Redis.new(url: redis_url)
    end
  end
  module_function :redis
end
