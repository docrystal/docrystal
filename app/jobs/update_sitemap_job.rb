class UpdateSitemapJob < ActiveJob::Base
  queue_as :default

  def perform
    return unless Rails.env.production?

    SitemapGenerator::Sitemap.default_host = 'http://docrystal.org'

    SitemapGenerator::Sitemap.create do
      add(about_path)
      add(badge_path)
      add(search_path)

      Shard::Doc.joins(:shard).where.not(generated_at: nil).find_in_batches do |docs|
        docs.each do |doc|
          shard = doc.shard
          add(doc_serve_path(hosting: shard.hosting, owner: shard.owner, name: shard.name, sha: doc.sha, file: 'index.html'))
        end
      end
    end

    SitemapGenerator::Sitemap.ping_search_engines
  end
end
