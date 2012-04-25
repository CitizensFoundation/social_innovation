SocialInnovation::Application.routes.draw do
  mount Ckeditor::Engine => '/ckeditor'
  mount WillFilter::Engine => "/will_filter"
  mount Tr8n::Engine => "/tr8n"

  resources :categories

  match '/ideas/flag/:id' => 'ideas#flag'
  match '/ideas/abusive/:id' => 'ideas#abusive'
  match '/ideas/not_abusive/:id' => 'ideas#not_abusive'
  match '/admin/all_flagged' => 'admin#all_flagged'
  match '/admin/all_deleted' => 'admin#all_deleted'
  match '/users/list_suspended' => 'users#list_suspended'

  resources :sub_instances do
    member do
      get :email
      get :picture
      post :picture_save
    end
  end

  resources :users do
  	resource :password
  	resource :profile
  	collection do
  	  get :endorsements
  	  post :order
  	end
  	member do
  	  put :suspend
      put :unsuspend
      get :activities
      get :comments
  	  get :points
  	  get :discussions
  	  get :capital
  	  put :impersonate
  	  get :followers
  	  get :documents
  	  get :stratml
  	  get :ignorers
  	  get :following
  	  get :ignoring
  	  post :follow
  	  post :unfollow
  	  put :make_admin
  	  get :ads
  	  get :ideas
  	  get :signups
  	  post :endorse
  	  get :reset_password
  	  get :resend_activation
    end
    resources :messages
    resources :followings do
      collection do
        put :multiple
      end
    end
    resources :user_contacts, :as => "contacts" do
      collection do
        put :multiple
        get :following
        get :members
        get :not_invited
        get :invited
      end
    end
  end

  resources :settings do
    collection do
      get :signups
      get :picture
      post :picture_save
      get :legislators
      post :legislators_save
      get :delete
    end
  end

  resources :ideas do
  	member do
      put :flag_inappropriate
      get :flag
      put :bury
      put :compromised
      put :successful
      put :failed
      put :intheworks
      post :endorse
      get :endorsed
      get :opposed
      get :activities
      get :endorsers
      get :opposers
      get :discussions
      put :create_short_url
      post :tag
      put :tag_save
      get :points
      get :opposer_points
      get :endorser_points
      get :neutral_points
      get :everyone_points
      get :top_points
      get :idea_detail
      get :endorsed_points
      get :opposed_top_points
      get :endorsed_top_points
      get :comments
      get :documents
      get :idea_detail
      get :update_status
  	end
  	collection do
      get :yours
      get :yours_finished
      get :yours_top
      get :yours_ads
      get :yours_lowest
      get :yours_created
      get :network
      get :consider
      get :finished
      get :ads
      get :top
      get :top_24hr
      get :top_7days
      get :top_30days
      get :rising
      get :falling
      get :controversial
      get :random
      get :newest
      get :untagged
  	end
    resources :changes do
      member do
        put :start
        put :stop
        put :approve
        put :flip
        get :activities
      end
      resources :votes
    end
    resources :points
    resources :ads do
      collection do
        post :preview
      end
      member do
        post :skip
      end
    end
  end

  resources :activities do
    member do
      put :undelete
      get :unhide
    end
    resources :following_discussions, :as=>"followings"
    resources :comments do
      collection do
        get :more
      end
      member do
        get :unhide
        get :flag
        post :not_abusive
        post :abusive
      end
    end
  end

  resources :points do
    member do
      get :flag
      post :not_abusive
      post :abusive
      get :activity
      get :discussions
      post :quality
      post :unquality
      get :unhide
    end
    collection do
      get :newest
      get :revised
      get :your_ideas
      get :your_index
    end
    resources :revisions do
      member do
        get :clean
      end
    end
  end

  resources :color_schemes do
    collection do
      put :preview
    end
  end

  resources :instances do
    member do
      get :apis
    end
  end

  resources :widgets do
    collection do
      get :ideas
      get :discussions
      get :points
      get :preview_iframe
      post :preview
    end
  end

  resources :bulletins do
    member do
      post :add_inline
    end
  end

  resources :searches do
    collection do
      get :all
    end
  end

  resources :signups
  resources :endorsements
  resources :passwords
  resources :unsubscribes
  resources :notifications
  resources :pages
  resources :about
  resources :tags
  resource :session
  resources :delayed_jobs do
    member do
      get :top
      get :clear
    end
  end

  resource :open_id

  match '/' => 'home#index'
  match '/activate/:activation_code' => 'users#activate', :as => :activate, :activation_code => nil
  match '/signup' => 'users#new', :as => :signup
  match '/login' => 'sessions#new', :as => :login
  match '/logout' => 'sessions#destroy', :as => :logout
  match '/unsubscribe' => 'unsubscribes#new', :as => :unsubscribe
  match '/yours' => 'ideas#yours'
  match '/hot' => 'ideas#hot'
  match '/cold' => 'ideas#cold'
  match '/new' => 'ideas#new'
  match '/controversial' => 'ideas#controversial'
  match '/vote/:action/:code' => 'vote#index'
  match '/welcome' => 'home#index'
  match '/search' => 'searches#index'
  match '/splash' => 'splash#index'
  match '/issues' => 'issues#index'
  match '/issues.:format' => 'issues#index'
  match '/issues/:slug' => 'issues#show'
  match '/issues/:slug.:format' => 'issues#show'
  match '/issues/:slug/:action' => 'issues#index'
  match '/issues/:slug/:action.:format' => 'issues#index'
  match '/pictures/:short_name/:action/:id' => 'pictures#index'
  match ':controller' => '#index'
  match ':controller/:action' => '#index'
  match ':controller/:action.:format' => '#index'
  match '/:controller(/:action(/:id))'
end
  # The idea is based upon order of creation:
  # first created -> highest idea.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
