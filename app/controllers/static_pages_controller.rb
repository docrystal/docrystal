require 'sidekiq/api'

class StaticPagesController < ApplicationController
  def root
  end

  def about
    expires_in 1.day, public: true, must_revalidate: false
  end

  def badge
    expires_in 1.day, public: true, must_revalidate: false

    style = (%w(flat round plastic).include?(params[:style]) ? params[:style].to_s : 'flat')

    respond_to do |format|
      format.svg { render "badge#{ style ? "-#{style}" : '' }" }
      format.html
    end
  end

  def status
    render json: {
      db: ActiveRecord::Base.connection.active?,
      es: Elasticsearch::Model.client.ping,
      redis: Docrystal.redis.ping == 'PONG',
      octokit: Docrystal.octokit.rate_limit.as_json,
      sidekiq: Sidekiq::Stats.new.as_json['stats']
    }
  end
end
