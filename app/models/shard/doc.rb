class Shard::Doc < ActiveRecord::Base
  belongs_to :shard, touch: true
  has_many :refs, class_name: 'Shard::Ref', dependent: :destroy

  validates :shard, presence: true
  validates :sha, uniqueness: { scope: :shard_id }
  validates :github_commit, presence: true

  after_create :enqueue_job

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
    generated_at? || error?
  end

  def github_commit
    @github_commit ||= Docrystal.octokit.commit(shard.github_repository_name, sha)
  end

  def log_pusher_key
    "doc-log-#{Digest::SHA1.hexdigest(id.to_s)}"
  end

  def log_redis_key
    "doc/log/#{id}"
  end

  private

  def enqueue_job
    Shard::Doc::GenerateJob.perform_later(id)
  end
end
