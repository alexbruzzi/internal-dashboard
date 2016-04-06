module Dashboard
	module Client

		def self.registered(app)

      # Manage Clients
      app.get '/client_manage' do
      erb :manage_clients
      end
      # Manage Clients End Route

      # Add Client Form
      app.get '/add_client' do
        erb :add_client
      end
      # End Route

      # Create Client by requesting kong
      app.post '/add_client' do
        
        username = params['username']
        custom_id = params['custom_id']

        response = app.create_consumer(username, custom_id)
        
      return "Success"
      end
      # End Route

    end
	end
end