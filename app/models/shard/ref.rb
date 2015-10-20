class Shard::Ref < ActiveRecord::Base
  belongs_to :shard, touch: true
  belongs_to :doc, class_name: 'Shard::Doc'

  validates :shard, presence: true
  validates :doc, presence: true
  validates :name, presence: true, uniqueness: { scope: :shard_id }
  validates :github_ref, presence: true

  delegate :storage, :sha, :log_redis_key, :log_pusher_key, :generated?, :error?, :error, :error_description, to: :doc

  def github_ref
    @github_ref ||= Docrystal.octokit.ref(shard.github_repository_name, "heads/#{name}")
  rescue Octokit::NotFound
    @github_ref ||= Docrystal.octokit.ref(shard.github_repository_name, "tags/#{name}")
  end
end
