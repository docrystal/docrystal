class StaticPagesController < ApplicationController
  caches_action :root, :about

  caches_action :badge, cache_path: proc { badge_path(params.except(:controller, :action)) }

  def root
  end

  def about
  end

  def badge
    expires_in 1.month, public: true

    style = (%w(flat round plastic).include?(params[:style]) ? params[:style].to_s : 'flat')

    respond_to do |format|
      format.svg { render "badge#{ style ? "-#{style}" : '' }" }
      format.html
    end
  end
end
