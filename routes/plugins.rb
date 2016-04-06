module Dashboard
  module Plugins

    def self.registered(app)

      app.get '/api_plugins' do

        begin
          data = []
          url = 'plugins/'
          
          # id - A filter on the list based on the id field.
          # name - A filter on the list based on the name field.
          # api_id - A filter on the list based on the api_id field.
          # consumer_id - A filter on the list based on the consumer_id field.
          # size - default is 100  A limit on the number of objects to be returned
          # offset - A cursor used for pagination. offset is an object identifier that defines a place in the list. 
          payload = {
            name: "cors"
          }

          header = {
            "Content-Type" => "application/json"
          }

          data = kong_request(url, "GET", header, payload)
        rescue Exception => e
          @error = e.to_s
        end
        erb :api_plugins
      end

      # Manage Clients Rate Limit
      app.get '/rate_limiting' do

        begin
          @cluster = Cassandra.cluster
          @sessionKong = @cluster.connect('kong')
          @selectEventsApiStatement = @sessionKong.prepare(
            'SELECT id FROM kong.apis WHERE name=\'events\''
          )
          @selectKeyauthStatement = @sessionKong.prepare(
            'SELECT key FROM kong.keyauth_credentials WHERE consumer_id = ?'
          )
          @selectPluginsStatement = @sessionKong.prepare(
            'SELECT * FROM kong.plugins WHERE consumer_id = ?'
          )
          event_rows = @sessionKong.execute(@selectEventsApiStatement)

          events_id = event_rows.rows.first['id'].to_s

          @clients = []

          list_clients = app.consumerlist()

          list_clients.each do |row|

            args = [Cassandra::Uuid.new(row['id'].to_s)]
            key_rows = @sessionKong.execute(@selectKeyauthStatement, arguments: args)
            plugin_rows = @sessionKong.execute(@selectPluginsStatement, arguments: args)
            
            plugin_id = nil

            plugin_rows.rows.each do |plugin_row|
              if plugin_row['api_id'].to_s == events_id and plugin_row['name'] == 'rate-limiting'
                plugin_id = plugin_row['id'].to_s
              end
            end

            if plugin_id
              # Plugin ID exists
            else
              plugin_id = app.create_ratelimiting_plugin( events_id, row['id'].to_s)
            end

            data = { :id => row['id'].to_s, :custom_id => row['username'].to_s, :authkey => key_rows.rows.first['key'].to_s, :pluginid => plugin_id.to_s }
            @clients.push(data)

          end
          erb :ratelimit
        rescue Exception => e
          print e.to_s
        end

      end
      # End Manage Clients

      # Update Client requests day limit
      app.post '/plugins/update' do

        plugin_id = params['plugin_id']
        day_limit = params['day_limit']
        consumer_id = params['consumer_id']
        apikey = params['apikey']

        begin

          payload = {
            consumer_id: consumer_id.to_s,
            config: {
              day: day_limit.to_s
            }
          }.to_json

          header = {
            'apikey' => apikey.to_s,
            'consumer_id' => consumer_id.to_s,
            'name' => 'rate-limiting',
            'Content-Type' => 'application/json'
          }

          url = 'plugins/' + plugin_id.to_s

          response = kong_request(url, "PATCH", header, payload)
          return "success"
        rescue Exception => e
          print e.to_s
          return "Error"
        end
      return "success"
      end
      # End Plugin Update

      # helper function to create plugin if not exist
      public def create_ratelimiting_plugin(apikey, consumer_id)

        url = 'apis/' + apikey.to_s + '/plugins/'
        payload = {
          name: "rate-limiting",
          consumer_id: consumer_id.to_s,
          config: {
            day: "1000000"
          }
        }.to_json
        header = { 
          'apikey' => apikey.to_s,
          'Content-Type' => "application/json"
        }

        response = kong_request(url, "POST", header, payload)
        if response['id']
          return response['id']
        end
        return ""
      end
      # end helper method

    end
  end
end