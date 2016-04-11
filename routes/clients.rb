module Dashboard
	module Client

		def self.registered(app)

      # Manage Clients
      app.get '/client_manage' do
        erb :manage_clients
      end

      # Add Client Form
      # Display add client form
      app.get '/add_client' do
        erb :add_client
      end

      # Create Client by requesting kong
      # @return [String] Status of request
      app.post '/add_client' do
        
        username = params['username']
        email = params['email']
        password = params['password']

        create_consumer(username, email, password)
      end

    end
	end
end