module Dashboard
	module Templates
		def self.registered(app)

			# Notification Templates
			app.get '/notification_templates' do

			  @cluster = Cassandra.cluster
			  @sessionOcto = @cluster.connect(KEYSPACE)
			  @selectTemplatesStatement = @sessionOcto.prepare(
			    'SELECT id, category_type FROM octo.template_categories'
			  )
			  result = @sessionOcto.execute(@selectTemplatesStatement)
			  @categories = []
			  @clients = []

			  if result
			    result.rows.each do |r|
			      temp = {:id => r['id'].to_s, :category_type => r['category_type'].to_s}
			      @categories.push(temp)
			    end
			  end
			  @sessionKong = @cluster.connect('kong')
			  @selectConsumersStatement = @sessionKong.prepare(
			    'SELECT id, custom_id FROM kong.consumers'
			  )
			  result = @sessionKong.execute(@selectConsumersStatement)
			  if result
			    result.rows.each do |r|
			      temp = {:id => r['id'].to_s, :custom_id => r['custom_id'].to_s}
			      @clients.push(temp)
			    end
			  end
			  erb :templates
			end
			# end route

			# Update Template Text wrt client
			app.post '/templates/update' do

			  templateCategory = params['templateCategory']
			  templateText = params['templateText']
			  templateState = params['templateState']
			  clientId = params['clientId']
			  @cluster = Cassandra.cluster
			  @sessionOcto = @cluster.connect(KEYSPACE)
			  @insertTemplatesStatement = @sessionOcto.prepare(
			    'INSERT INTO octo.templates (enterpriseid, tcid, active, template_text) VALUES ( ' + clientId + ', ' + templateCategory + ', ' + templateState + ', \'' + templateText + '\')'
			  )
			  result = @sessionOcto.execute(@insertTemplatesStatement)
			return "success"
			end
			# end route


			# Get Template Text wrt client and template category for updation
			app.get '/templates_text' do

			  begin
			    templateCategory = params['templateCategory']
			    clientId = params['clientId']
			    @cluster = Cassandra.cluster
			    @sessionOcto = @cluster.connect(KEYSPACE)
			    @selectTextStatement = @sessionOcto.prepare(
			      "SELECT template_text FROM octo.templates WHERE enterpriseid = ? AND tcid = ?"
			    )
			    args = [Cassandra::Uuid.new(clientId), Cassandra::Uuid.new(templateCategory)]
			    result = @sessionOcto.execute(@selectTextStatement, arguments: args)
			    text = ""
			    result.rows.each do |r|
			      text = r['template_text']
			    end

			  rescue Exception => e
			    text = ""
			    print e.to_s
			  end
			return text
			end
			# end route

		end
	end
end