class Shard < ActiveRecord::Base
  has_many :docs, class_name: 'Shard::Doc'
end
