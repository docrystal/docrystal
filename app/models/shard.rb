class Shard < ActiveRecord::Base
  has_many :docs, class_name: 'Shard::Doc'

  validates :hosting, presence: true
  validates :owner, presence: true
  validates :name, presence: true, uniqueness: { scope: %i(hosting owner) }

  def full_name
    "#{hosting}/#{owner}/#{name}"
  end

  def git_url
    "https://#{hosting}/#{owner}/#{name}.git"
  end
end
