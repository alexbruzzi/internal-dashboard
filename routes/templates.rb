require 'cequel'

module Dashboard
  module Templates

    def self.registered(app)

      # Request Categories Page
      # Display category page
      app.get '/template_categories' do

        @clients = []
        consumerlist.each do |r|
          temp = {:id => r['custom_id'].to_s, :username => r['username']}
          @clients.push(temp)
        end
        erb :category
      end

      # Fetch all categories
      # @return [JSON] Categories List
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
          @error = e.to_s
        end
        @categories.to_json
      end

      # Add a new category
      # @return [String] Status of request
      app.post '/add_category' do

        begin
          clientId = params['clientId']
          category_type = params['category_type']
          Octo::Template.findOrCreate({enterprise_id: clientId, category_type: category_type})
        rescue Exception => e
          @error = e.to_s
        end
        "success"
      end

      # Get all Notification Templates
      # Display templates page
      app.get '/notification_templates' do

        @clients = []
        consumerlist.each do |r|
          temp = {:id => r['custom_id'].to_s, :username => r['username']}
          @clients.push(temp)
        end
        erb :templates
      end
      # end route

      # Update Notification Template
      # @return [String] Status of request
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
          @error = e.to_s
          return "error"
        end
        "success"
      end

      # Get Notification Template details 
      # @return [JSON] Template details
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
          @error = e.to_s
        end

        # Create Json Response
        { text: text, state: state }.to_json
      end

    end
  end
end