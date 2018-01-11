# A sample Guardfile
# More info at https://github.com/guard/guard#readme

# Load user specific settings
if File.exists?('Guardfile.local')
  instance_eval File.read('Guardfile.local')
end

guard :bundler do
  watch('Gemfile')
  # Uncomment next line if your Gemfile contains the `gemspec' command.
  # watch(/^.+\.gemspec/)
end

guard 'rails', port: 3030 do
  watch('Gemfile.lock')
  watch(%r{^(config|lib)/.*})
end

### Guard::Sidekiq
#  available options:
#  - :verbose
#  - :queue (defaults to "default") can be an array
#  - :concurrency (defaults to 1)
#  - :timeout
#  - :environment (corresponds to RAILS_ENV for the Sidekiq worker)
guard 'sidekiq', :environment => 'development' do
  watch(%r{^app/workers/(.+)\.rb$})
end


