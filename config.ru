# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment', __FILE__)
require 'unicorn/worker_killer'

# Max requests per worker
max_request_min =  3072
max_request_max =  4096
use Unicorn::WorkerKiller::MaxRequests, max_request_min, max_request_max

use Rack::CanonicalHost, 'docrystal.org' if Rails.env.production?
run Rails.application
