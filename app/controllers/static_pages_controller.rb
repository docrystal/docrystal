require 'sidekiq/api'

class StaticPagesController < ApplicationController
  before_filter :set_cache_control_headers, only: [:root, :about, :badge]

  def root
    set_surrogate_key_header Shard.table_key
  end

  def about
    set_surrogate_key_header revision
  end

  def badge
    set_surrogate_key_header revision

    style = (%w(flat round plastic).include?(params[:style]) ? params[:style].to_s : 'flat')

    respond_to do |format|
      format.svg { render "badge#{ style ? "-#{style}" : '' }" }
      format.html
    end
  end

  def status
    expires_in(5.seconds, public: false, must_revalidate: true)
    expires_now

    render json: {
      revision: revision,
      db: ActiveRecord::Base.connection.active?,
      es: Elasticsearch::Model.client.ping,
      redis: Docrystal.redis.ping == 'PONG',
      octokit: Docrystal.octokit.rate_limit.as_json,
      sidekiq: Sidekiq::Stats.new.as_json['stats']
    }
  end

  private

  def revision
    if File.exists?(Rails.root.join('REVISION'))
      File.read(Rails.root.join('REVISION'))
    else
      `git rev-parse HEAD`.strip
    end
  end
end
