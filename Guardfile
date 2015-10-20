# vim: ft=ruby
clearing :off
interactor :off

guard :bundler do
  require 'guard/bundler'
  require 'guard/bundler/verify'
  helper = Guard::Bundler::Verify.new

  files = ['Gemfile']
  files += Dir['*.gemspec'] if files.any? { |f| helper.uses_gemspec?(f) }

  files.each { |file| watch(helper.real_path(file)) }
end

guard 'rails' do
  watch('Gemfile.lock')
  watch(%r{^(config|lib)/.*})
end

guard 'sidekiq', environment: 'development' do
  watch('Gemfile.lock')
  watch(%r{^(config|lib)/.*})
  watch(%r{^app/jobs/(.+)\.rb$})
  watch(%r{^app/models/(.+)\.rb$})
end
