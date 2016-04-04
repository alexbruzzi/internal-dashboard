module Dashboard
  module UuidTrack
    def self.registered(app)
      
      # Track UUID's
      app.get '/uuid_track' do
        erb :track
      end
      # end route

      # Get uuid details (to track uuids)
      app.get '/uuid_details' do
        
        service_type = params['service_type']
        uuid_value = params['uuid_value'] # uuid_value = "bce946c6-e167-4b50-b145-1700eafa889b"
        response = []
        begin

          case service_type
          when "app_init"
            Octo::AppInit.where(customid: uuid_value).each do |r|
              response.push(r.to_s)
            end
          when "app_login"
            Octo::AppLogin.where(customid: uuid_value).each do |r|
              response.push(r.to_s)
            end
          when "app_logout"
            Octo::AppLogout.where(customid: uuid_value).each do |r|
              response.push(r.to_s)
            end
          when "page_view"
            Octo::Page.where(customid: uuid_value).each do |r|
              response.push(r.to_s)
            end
          when "productpage_view"
            Octo::Product.where(customid: uuid_value).each do |r|
              response.push(r.to_s)
            end
          end
        rescue Exception => e
          return "Error"
        end
      return response
      end
      # end route

    end
  end
end