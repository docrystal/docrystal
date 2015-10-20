class Shard::Doc < ActiveRecord::Base
  belongs_to :shard

  validates :shard, presence: true
  validates :sha, uniqueness: { scope: :shard_id }
  validates :github_commit, presence: true

  def self.by_sha(sha)
    find_or_create_by(sha: sha)
  end

  def self.by_sha!(sha)
    find_by!(sha: sha)
  end

  def storage
    @storage ||= Docrystal::Storage.new("#{shard.full_name}/#{sha}")
  end

  def name
    sha
  end

  def generated?
    generated_at?
  end

  def github_commit
    @github_commit ||= Octokit.commit(shard.github_repository_name, sha)
  end
end
