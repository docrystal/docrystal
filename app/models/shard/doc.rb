class Shard::Doc < ActiveRecord::Base
  belongs_to :shard

  validates :shard, presence: true
  validates :sha, uniqueness: { scope: :shard_id }

  def self.by_sha(sha)
    find_or_create_by(sha: sha)
  end

  def storage
    @storage ||= Docrystal::Storage.new("#{shard.full_name}/#{sha}")
  end
end
