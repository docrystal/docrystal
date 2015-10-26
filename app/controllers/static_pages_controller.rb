require 'sidekiq/api'

class StaticPagesController < ApplicationController
  before_filter :set_fastly_header, only: [:about, :badge]

  def root
    set_cache_control_headers(1.hour, cache_control: '')
    expires_in(10.minutes, public: true, must_revalidate: false)
    set_surrogate_key_header Shard.table_key
  end

  def about
    expires_in(1.day, public: true, must_revalidate: false)
    set_surrogate_key_header revision
  end

  def badge
    expires_in(1.day, public: true, must_revalidate: false)
    set_surrogate_key_header revision

    style = (%w(flat round plastic).include?(params[:style]) ? params[:style].to_s : 'flat')

    respond_to do |format|
      format.svg { render "badge#{ style ? "-#{style}" : '' }" }
      format.html
    end
  end

  def status
    expires_in(5.seconds, public: false, must_revalidate: true)

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
      File.read(Rails.root.join('REVISION')).strip
    else
      `git rev-parse HEAD`.strip
    end
  end

  def set_fastly_header
    set_cache_control_headers(FastlyRails.configuration.max_age, cache_control: '')
  end
end
