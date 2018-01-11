source 'https://rubygems.org'
ruby '2.2.0'

gem 'rails', '4.2.0'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails'
gem 'jquery-turbolinks'
# gem 'turbolinks' # not playing nice with angular plasmid
gem 'jbuilder', '~> 2.0'
gem 'sdoc', '~> 0.4.0',          group: :doc
gem 'spring',        group: :development
gem 'sass'
gem 'materialize-sass'
gem 'mysql2', '~> 0.3.20'
gem 'puma'
gem 'slim-rails'
gem 'rename'
gem 'html2slim', '~> 0.2.0'
gem 'paperclip', "~> 4.3.0"
gem 'bio', '~> 1.5'
gem 'sidekiq'
gem 'sidekiq-status'
gem 'sinatra', :require => false # for sinatra interface
# gem 'sidekiq-priority'
gem 'redis-rails'
gem 'redis-namespace'
gem 'jquery-datatables-rails', github: 'rweng/jquery-datatables-rails'
gem 'wishart', git: 'git@bitbucket.org:wishartlab/wishart'
gem 'rubyzip'
gem 'data_uri'
gem 'remotipart', '~> 1.2'
gem 'jquery-fileupload-rails', github: 'Springest/jquery-fileupload-rails'
gem 'net-ssh'
gem 'net-sftp'
gem 'newrelic_rpm'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller', :platforms=>[:mri_21]
  gem 'capistrano', '~> 3.2.0'
  gem 'capistrano-bundler'
  gem 'capistrano-rails', '~> 1.1.0'
  gem 'capistrano-rails-console'
  gem 'capistrano-rvm', '~> 0.1.1'
  gem 'capistrano-sidekiq'
  gem 'quiet_assets'
  gem 'rails_layout'
  gem 'guard-bundler'
  gem 'guard-rails'
  gem 'guard-sidekiq'
  gem 'syncfast', git: 'git@bitbucket.org:wishartlab/syncfast'
end
group :development, :test do
  gem 'pry-rails'
  gem 'pry-rescue'
end

group :production do
  gem 'capistrano-bundler'
  gem 'capistrano-rails', '~> 1.1.0'
  gem 'capistrano-rails-console'
  gem 'capistrano-rvm', '~> 0.1.1'
  gem 'capistrano-sidekiq'
  gem 'execjs'
  gem 'therubyracer', require: 'v8'
end
