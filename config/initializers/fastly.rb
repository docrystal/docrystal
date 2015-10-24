FastlyRails.configure do |c|
  c.api_key = ENV['FASTLY_API_KEY']
  c.max_age = 30.days
  c.service_id = ENV['FASTLY_SERVICE_ID']
  c.purging_enabled = !Rails.env.development?
end
