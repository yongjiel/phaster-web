require 'sidekiq/web'

Rails.application.routes.draw do

  resources :submissions, only: [:index, :show, :new, :create, :destroy, :split], id: /[\w.]+?/, format: /json|csv|xml|js|zip/ do
    get 'status', on: :member
    post 'download', on: :collection
  end

  resources :batches, only: :show, id: /[\w.]+?/, format: /json|csv|xml|js|zip/ do
  end

  get 'phaster_api' => 'phaster_api#show'
  post 'phaster_api' => 'phaster_api#post_file'
  #post 'phaster_api' => 'phaster_api#post_file_maintenance' # use when site down for maintenance

  # don't give phast documentation, maybe later update phaster documenation
  # get 'documentation' => 'home#documentation', :as => :documentation

  get 'instructions' => 'home#instructions', :as => :instructions
  get 'statistics' => 'home#statistics', :as => :statistics
  get 'output' => 'home#output', :as => :output
  get 'input' => 'home#input', :as => :input
  # get 'url_api' => 'home#url_api', :as => :url_api
  get 'databases' => 'home#databases', :as => :databases
  get 'contact' => 'home#contact', :as => :contact
  get 'my_searches' => 'submissions#my_searches', :as => :my_searches
  get 'additional_downloads' => 'home#additional_downloads', :as => :additional_downloads # secret page shared manually

  root :to => "submissions#new"
  #root :to => "submissions#maintenance" # use when site down for maintenance
  #get 'test' => 'submissions#new', :as => :test # secret page for submitting jobs when site is under maintenance

  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      username == 'admin' && password == 'c4odt8gqmUcfwMCH82'
    end
  end
  mount Sidekiq::Web, at: '/sidekiq'

end
