class Shard < ActiveRecord::Base
  HOSTINGS = %w(github.com)
  GITHUB_USER_NAME_REGEXP = %r{[a-zA-Z0-9](?:[a-zA-Z0-9-]+)}
  GITHUB_REPO_NAME_REGEXP = %r{[^/]+}
  GITHUB_COMMITISH_REGEXP = %r{[^/]+}
  GITHUB_URL_REGEXP = %r{https?://github\.com/(?<owner>#{GITHUB_USER_NAME_REGEXP})/(?<repo>#{GITHUB_REPO_NAME_REGEXP})(?:$|/)}x
  GITHUB_URL_WITH_COMMITISH_REGEXP = %r{https?://github\.com/(?<owner>#{GITHUB_USER_NAME_REGEXP})/(?<repo>#{GITHUB_REPO_NAME_REGEXP})/tree/(?<commitish>#{GITHUB_COMMITISH_REGEXP})}x

  has_many :docs, class_name: 'Shard::Doc', dependent: :destroy
  has_many :refs, class_name: 'Shard::Ref', dependent: :destroy

  validates :hosting, presence: true, inclusion: { in: HOSTINGS }
  validates :owner, presence: true, format: { with: GITHUB_USER_NAME_REGEXP }
  validates :name, presence: true, uniqueness: { scope: %i(hosting owner) }, format: { with: GITHUB_REPO_NAME_REGEXP }
  validates :github_repository, presence: true

  def full_name
    "#{hosting}/#{owner}/#{name}"
  end

  def git_url
    "https://#{hosting}/#{owner}/#{name}.git"
  end

  def github_repository_name
    "#{owner}/#{name}"
  end

  def github_repository
    @github_repository ||= Octokit.repository(github_repository_name)
  end

  def default_branch
    github_repository.default_branch
  end

  def github_branches
    @github_branches ||= Hash[*(
      Octokit.branches(github_repository_name).map { |branch| [branch.name, branch] }.flatten
    )]
  end

  def github_tags
    @github_tags ||= Hash[*(
      Octokit.tags(github_repository_name).map { |tag| [tag.name, tag] }.flatten
    )]
  end

  def lookup_ref(name)
    obj = github_branches[name] || github_tags[name]

    return docs.find_by(sha: name) unless obj

    doc = docs.by_sha(obj.commit.sha)
    ref = refs.find_or_initialize_by(name: name)
    ref.update!(doc: doc) if ref.doc_id != doc.id

    ref
  end
end
