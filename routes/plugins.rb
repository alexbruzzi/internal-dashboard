module Dashboard
  module Plugins

    def self.registered(app)

      # Manage plugins
      # Display manage plugins page
      app.get '/api_plugins' do

        erb :api_plugins
      end

      # Ratelimiting plugin page reuest
      # Display ratelimiting page
      app.get '/rate_limiting' do

        begin
          url = '/apis/events'
          payload = {}
          events = process_kong_request(url, :GET, payload)
          events_id = events['id'].to_s

          @clients = []

          consumerlist.each do |row|
            consumer_id = row['id'].to_s

            plugin_url = '/plugins/?name=rate-limiting&api_id='+events_id+'&consumer_id='+consumer_id
            plugin_rows = process_kong_request(plugin_url, :GET, {})
            
            if plugin_rows['total'] > 0
              # Plugin ID exists
              plugin_id = plugin_rows['data'].first['id']
            else
              plugin_id = create_ratelimiting_plugin( events_id, consumer_id)
            end

            data = { id: consumer_id, custom_id: row['username'], pluginid: plugin_id }
            @clients.push(data)

          end
        rescue Exception => e
          @error = e.to_s
        end
        erb :ratelimit
      end

      # Fetch Ratelimiting plugin details or configuration
      # @return [JSON] Plugin Configuration
      app.get '/rate_limiting/details' do
        begin
          plugin_id = params['plugin_id']

          url = '/plugins/' + plugin_id
          plugin_details = process_kong_request(url, :GET, {})
          plugin_details['config'].to_json
        rescue Exception => e
          @error = e.to_s
        end
      end

      # Update Client Ratelimiting Plugin
      # @return [JSON] Plugin Configuration
      # @return [String] Eror If any error Occur 
      app.post '/rate_limiting/update' do

        plugin_id = params['plugin_id']
        consumer_id = params['consumer_id']
        config = params['config']

        begin
          payload = {
            name: 'rate-limiting',
            consumer_id: consumer_id,
            config: config
          }

          url = '/apis/events/plugins/' + plugin_id
          response = process_kong_request(url, :PATCH, payload)
          return response['config'].to_json
        rescue Exception => e
          @error = e.to_s
          return "error"
        end
        "Unable to Update"
      end

    end
  end
end