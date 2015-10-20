class Shard::Doc < ActiveRecord::Base
  belongs_to :shard

  validates :shard
  validates :sha, uniqueness: { scope: :shard_id }
end
