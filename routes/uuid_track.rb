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
			    @cluster = Cassandra.cluster
			    @sessionOcto = @cluster.connect(KEYSPACE)
			    @selectUuidStatement = @sessionOcto.prepare(
			      'SELECT * FROM octo.' + service_type + ' WHERE id=' + uuid_value
			    )
			    result = @sessionOcto.execute(@selectUuidStatement)

			    if result
			      result.rows.each do |r|
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