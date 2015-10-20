class Shard < ActiveRecord::Base
  include Searchable

  HOSTINGS = %w(github.com)
  GITHUB_USER_NAME_REGEXP = %r{[a-zA-Z0-9](?:[a-zA-Z0-9-]+)}
  GITHUB_REPO_NAME_REGEXP = %r{[^/]+}
  GITHUB_COMMITISH_REGEXP = %r{[^/]+}
  GITHUB_URL_REGEXP = %r{https?://github\.com/(?<owner>#{GITHUB_USER_NAME_REGEXP})/(?<repo>#{GITHUB_REPO_NAME_REGEXP})(?:$|/)}x
  GITHUB_URL_WITH_COMMITISH_REGEXP = %r{https?://github\.com/(?<owner>#{GITHUB_USER_NAME_REGEXP})/(?<repo>#{GITHUB_REPO_NAME_REGEXP})/tree/(?<commitish>#{GITHUB_COMMITISH_REGEXP})}x

  BOOST_SETTINGS = [
    [%i(full_name), 100],
    [%i(repo_name), 50],
    [%i(name), 20],
    [%i(full_name_ngram), 5]
  ]

  SEARCH_FIELDS = BOOST_SETTINGS.map do |field, _boost_factor|
    field
  end

  has_many :docs, class_name: 'Shard::Doc', dependent: :destroy
  has_many :refs, class_name: 'Shard::Ref', dependent: :destroy

  validates :hosting, presence: true, inclusion: { in: HOSTINGS }
  validates :owner, presence: true, format: { with: GITHUB_USER_NAME_REGEXP }
  validates :name, presence: true, uniqueness: { scope: %i(hosting owner) }, format: { with: GITHUB_REPO_NAME_REGEXP }
  validates :github_repository, presence: true

  settings do
    mappings dynamic: 'false' do
      indexes :full_name, index: 'not_analyzed'
      indexes :repo_name, index: 'not_analyzed'
      indexes :name, index: 'not_analyzed'
      indexes :full_name_ngram, analyzer: 'repo_ngram'
    end
  end

  def self.boosted_search(query)
    body = {}

    functions = BOOST_SETTINGS.map do |fields, boost_factor|
      {
        filter: {
          query: {
            simple_query_string: {
              query: query,
              fields: fields,
              default_operator: :and
            }
          }
        },
        boost_factor: boost_factor
      }
    end

    body[:query] = {
      function_score: {
        score_mode: :multiply,
        query: {
          simple_query_string: {
            query: query,
            fields: SEARCH_FIELDS,
            default_operator: :and
          }
        },
        functions: functions
      }
    }

    search(body).records
  end

  def as_indexed_json(*)
    {
      full_name: full_name,
      repo_name: "#{owner}/#{name}",
      name: name,
      full_name_ngram: full_name
    }
  end

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
