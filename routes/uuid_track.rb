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
        
        service_type = params['service_type']
        uuid_value = params['uuid_value']
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
          response
        rescue Exception => e
          "Wrong UUID Value"
        end
      end

    end
  end
end