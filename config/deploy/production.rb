# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# server 'example.com', user: 'deploy', roles: %w{app db web}, my_property: :my_value
# server 'example.com', user: 'deploy', roles: %w{app web}, other_property: :other_value
# server 'db.example.com', user: 'deploy', roles: %w{db}
digitalocean = DropletKit::Client.new(access_token: ENV['DIGITALOCEAN_API_TOKEN'])

# role-based syntax
# ==================

# Defines a role with one or multiple servers. The primary server in each
# group is considered to be the first unless any  hosts have the primary
# property set. Specify the username and a domain or IP for the server.
# Don't use `:all`, it's a meta role.

droplets = digitalocean.droplets.all.select do |droplet|
  droplet.name =~ /\Adocrystal-rails-\d+\Z/
end

droplet_ips = droplets.map do |droplet|
  droplet.networks.v4.select { |ip| ip.type == 'public' }.first.ip_address
end

role :app, droplet_ips
role :web, droplet_ips
role :db, droplet_ips


set :linked_files, fetch(:linked_files, []).push(
  '.env.production'
)

set :ssh_options, {
  user: 'docrystal',
  forward_agent: false,
  auth_methods: %w(publickey)
}
