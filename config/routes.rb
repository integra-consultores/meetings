# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get '/projects/:project_id/meetings/new', :to => "meetings#new", :as => :new_meeting
get '/projects/:project_id/meetings' , :to => "meetings#index", :as => :project_meetings
post '/projects/:project_id/meetings' , :to => "meetings#create"
match '/meetings/auto_complete', :to => 'meetings#meetings', :via => :get, :as => 'auto_complete_meetings'
resources :meetings , :except => [:new] do
  resources :time_entries, :controller => 'timelog' do
    collection do
      get 'report'
    end
  end
end


