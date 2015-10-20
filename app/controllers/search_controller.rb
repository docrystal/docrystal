class SearchController < ApplicationController
  def show(q = '')
    @shards = Shard.boosted_search(q)
  end
end
