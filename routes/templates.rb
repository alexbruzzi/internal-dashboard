require 'cequel'

module Dashboard
  module Templates

    def self.registered(app)

      def checkEnterprise(enterpriseId)
        return Octo::Enterprise.findOrCreate({id: enterpriseId})
      end

      app.get '/template_categories' do

        @cluster = Cassandra.cluster
        @sessionKong = @cluster.connect('kong')
        @selectConsumersStatement = @sessionKong.prepare(
          'SELECT id, custom_id, username FROM kong.consumers'
        )
        result = @sessionKong.execute(@selectConsumersStatement)
        @clients = []
        if result
          result.rows.each do |r|
            temp = {:id => r['id'].to_s, :custom_id => r['username'].to_s}
            @clients.push(temp)
          end
        end
      erb :category
      end

      app.get '/fetch_categories' do
        content_type :json
        clientId = params['clientId']

        begin
          @categories = []
          Octo::Template.where(enterprise_id: clientId).each do |r|
            temp = {:category_type => r[:category_type].to_s}
            @categories.push(temp)
          end
        rescue Exception => e
          print e.to_s
        end
      return @categories.to_json
      end

      app.post '/add_category' do

        begin
          clientId = params['clientId']
          category_type = params['category_type']
          Octo::Template.findOrCreate({enterprise_id: clientId, category_type: category_type})
        rescue Exception => e
          print e.to_s
        end
      return "success"
      end

      # Notification Templates
      app.get '/notification_templates' do

        @clients = []
        @cluster = Cassandra.cluster
        @sessionKong = @cluster.connect('kong')
        @selectConsumersStatement = @sessionKong.prepare(
          'SELECT id, custom_id, username FROM kong.consumers'
        )
        result = @sessionKong.execute(@selectConsumersStatement)
        if result
          result.rows.each do |r|
            temp = {:id => r['id'].to_s, :custom_id => r['username'].to_s}
            @clients.push(temp)
          end
        end
        erb :templates
      end
      # end route

      # Update Template Text wrt client
      app.post '/template_update' do

        templateCategory = params['templateCategory']
        templateText = params['templateText']
        templateState = params['templateState']
        clientId = params['clientId']

        begin
          args = {
            enterprise_id: clientId,
            category_type: templateCategory
          }
          options = {
            active: templateState,
            template_text: templateText
          }
          Octo::Template.findOrCreateOrUpdate(args, options)

        rescue Exception => e
          print e.to_s
        end
      return "success"
      end
      # end route

      # Get Template Text wrt client and template category for updation
      app.get '/templates_text' do

        clientId = params['clientId']
        templateCategory = params['templateCategory']
        
        text = ""
        state = false
        begin
          args = {
            enterprise_id: clientId,
            category_type: templateCategory
          }
          result = Octo::Template.findOrCreate(args)

          text = result[:template_text]
          state = result[:active]

        rescue Exception => e
          print e.to_s
        end

        # Create Json Response
        response = {
            text: text,
            state: state
          }.to_json
      return response
      end
      # end route

    end
  end
end