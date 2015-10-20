stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, store: Rails.cache, serializer: Oj, logger: Rails.logger
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack

module Docrystal
  def octokit
    RequestStore.fetch(:octokit) do
      Octokit::Client.new(
        client_id: ENV['OCTOKIT_CLIENT_ID'],
        client_secret: ENV['OCTOKIT_CLIENT_SECRET']
      )
    end
  end
  module_function :octokit
end
