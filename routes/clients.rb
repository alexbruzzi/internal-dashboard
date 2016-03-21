module Dashboard
	module Client

		def self.registered(app)

      # Manage Clients
      app.get '/clients_manage' do

        begin
          @cluster = Cassandra.cluster
          @sessionKong = @cluster.connect('kong')
          @selectConsumersStatement = @sessionKong.prepare(
            'SELECT id, custom_id FROM kong.consumers'
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
          client_rows = @sessionKong.execute(@selectConsumersStatement)
          event_rows = @sessionKong.execute(@selectEventsApiStatement)

          events_id = event_rows.rows.first['id'].to_s

          @clients = []

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
              plugin_id = app.create_ratelimiting_plugin( events_id, row['id'].to_s)
            end

            data = { :id => row['id'].to_s, :custom_id => row['custom_id'].to_s, :authkey => key_rows.rows.first['key'].to_s, :pluginid => plugin_id.to_s }
            @clients.push(data)

          end
          erb :manage
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

        @payload = {
          "consumer_id" => consumer_id.to_s,
          "config" => {
            "day" => day_limit.to_s
          }
        }.to_json

        url = 'http://127.0.0.1:8001/plugins/' + plugin_id

        begin
          uri = URI.parse('http://127.0.0.1:8001/plugins/' + plugin_id.to_s)
          http = Net::HTTP.new(uri.host,uri.port)
          req = Net::HTTP::Patch.new(uri.path, initheader = { 'apikey' => apikey.to_s, 'Content-Type' => 'application/json', 'consumer_id' => consumer_id.to_s, 'name' => 'rate-limiting' })

          req.body = "#{@payload}"
          res = http.request(req)

          response = JSON.parse(res.body)
          return "success"
        rescue Exception => e
          print e.to_s
          return "Error"
        end
      return "success"
      end
      # End Plugin Update

      # helper function to create plugin if not exist
      def create_ratelimiting_plugin(apikey, consumer_id)

        headers = {
          "apikey" => apikey.to_s,
          "Content-Type" => "application/json"
        }

        @payload = {
          "name" => "rate-limiting",
          "consumer_id" => consumer_id.to_s,
          "config" => {
            "day" => "100000"
          }
        }.to_json

        url = 'http://127.0.0.1:8001/apis/' + apikey.to_s + '/plugins/'

        begin

          uri = URI.parse('http://127.0.0.1:8001/apis/' + apikey.to_s + '/plugins/')
          http = Net::HTTP.new(uri.host,uri.port)
          req = Net::HTTP::Post.new(uri.path, initheaders = { 'apikey' => apikey.to_s, 'Content-Type' => "application/json" })

          req.body = "#{@payload}"
          res = http.request(req)

          response = JSON.parse(res.body)

        rescue Exception => e
          print e.to_s
        end

      return response['id']
      end
      # end helper method

    end
	end
end