class SearchController < ApplicationController
  def show(q = '')
    @shards = Shard.boosted_search(q)
  end

  def opensearch
    response.headers['Content-Type'] = 'application/opensearchdescription+xml; charset=utf-8'
  end
end
