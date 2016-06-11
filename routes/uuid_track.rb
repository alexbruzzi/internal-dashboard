module Dashboard
  module UuidTrack
    def self.registered(app)
      
      # Track UUID's
      # Display UUID tracking form
      app.get '/uuid_track' do
        erb :track
      end

      # Get uuid details
      # @return [String] Get UUID details
      app.get '/uuid_details' do
        
        # service_type = params['service_type']
        uuid_value = params['uuid_value']
        response = nil
        
        begin
          res = Octo::ApiTrack.where(customid: uuid_value).first
          response = res[:json_dump]
          response.to_json
        rescue Exception => e
          "Wrong UUID Value"
        end
      end

    end
  end
end