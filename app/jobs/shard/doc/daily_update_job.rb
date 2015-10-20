class Shard::Doc::DailyUpdateJob < ActiveJob::Base
  queue_as :default

  def perform(shard_id = nil)
    return update_all_shards if shard_id.nil?

    @shard = Shard.find(shard_id)

    @shard.github_branches.keys.each do |branch|
      @shard.lookup_ref(branch)
    end

    @shard.github_tags.keys.each do |tag|
      @shard.lookup_ref(tag)
    end
  rescue
  end

  private

  def update_all_shards
    Shard.pluck(:id).each do |id|
      Shard::Doc::DailyUpdateJob.perform_later(id)
    end
  end
end
