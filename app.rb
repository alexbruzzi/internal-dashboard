require 'rubygems'
require 'sinatra'
require 'securerandom'
require 'json'
require 'cassandra'
require 'net/http'
require 'uri'
require 'digest/sha1'

KEYSPACE = 'octo'

configure do
  enable :sessions
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello Stranger'
  end
end

before do
  pass if %w[login].include? request.path_info.split('/')[1]
  unless session[:identity]
    session[:previous_url] = request.path
    halt erb(:login_form)
  end
end

# Root URL
get '/' do
  erb '<div class="page-header"> Welcome to OCTO Dashboard ! </div>'
end

# Display Login Form
get '/login' do
  erb :login_form
end

# Perform Login
post '/login' do

  # Connects to localhost by default
  @cluster = Cassandra.cluster
  @sessionKong = @cluster.connect('kong')
  @selectUserStatement = @sessionKong.prepare(
    "SELECT username, password, consumer_id FROM kong.basicauth_credentials"
  )
  result = @sessionKong.execute(@selectUserStatement)
  if result
    result.rows.each do |r|
      if params['username'] == r['username'].to_s
        key = Digest::SHA1.hexdigest(params['password'] + r['consumer_id'].to_s)
        if key == r['password'].to_s
          session[:identity] = params['username']
          # where_user_came_from = session[:previous_url] || '/'
          redirect to '/'
        end
      end
    end
  end
  redirect to('/login')

end

# Perform Logout
get '/logout' do
  session.delete(:identity)
  redirect to('/login')
end

# Track UUID's
get '/uuid_track' do
  erb :track
end

# Get uuid details (to track uuids)
get '/uuid_details' do
  
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
  rescue 
    # Handle Error
    return "Error"
  end
return response
end

# Notification Templates
get '/notification_templates' do

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

# Update Template Text wrt client
post '/templates/update' do

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


# Get Template Text wrt client and template category for updation
get '/templates_text' do

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

# Manage Clients
get '/clients_manage' do

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
        plugin_id = create_ratelimiting_plugin( events_id, row['id'].to_s)
      end

      data = { :id => row['id'].to_s, :custom_id => row['custom_id'].to_s, :authkey => key_rows.rows.first['key'].to_s, :pluginid => plugin_id.to_s }
      @clients.push(data)

    end
    erb :manage
  rescue Exception => e
    print e.to_s
  end

end

# Manage Clients request day limit
post '/plugins/update' do

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