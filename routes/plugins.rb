module Dashboard
  module Plugins

    def self.registered(app)

      app.get '/api_plugins' do

         begin
          @error = []
          data = app.consumerlist()
          data.each do |d|
            print d
            @error.push(d['id'])
          end
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
          @selectConsumersStatement = @sessionKong.prepare(
            'SELECT id, custom_id, username FROM kong.consumers'
          )
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

          client_rows = @sessionKong.execute(@selectConsumersStatement)

          client_rows.rows.each do |row|

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
              plugin_id = create_ratelimiting_plugin( events_id, row['id'].to_s)
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

    end
  end
end