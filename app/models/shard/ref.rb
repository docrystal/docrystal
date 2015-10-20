class Shard::Ref < ActiveRecord::Base
  belongs_to :shard
  belongs_to :doc, class_name: 'Shard::Doc'

  validates :shard, presence: true
  validates :doc, presence: true
  validates :name, presence: true, uniqueness: { scope: :shard_id }

  delegate :storage, :sha, :generated?, to: :doc
end
