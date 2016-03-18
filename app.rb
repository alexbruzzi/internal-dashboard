require 'rubygems'
require 'sinatra'
require 'securerandom'
require 'json'
require 'cassandra'

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
    erb :login_form
    # @error = 'Sorry, you need to be logged in to visit ' + request.path
    # halt erb(:login_form)
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
  @sessionCass = @cluster.connect('kong')
  @selectUserStatement = @sessionCass.prepare(
    "SELECT username, password FROM kong.basicauth_credentials"
  )
  result = @sessionCass.execute(@selectUserStatement)
  if result and result.size == 1
    result.rows.each do |r|
      if params['username'] == r['username'].to_s
        session[:identity] = params['username']
        where_user_came_from = session[:previous_url] || '/'
        redirect to where_user_came_from
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

# 
get '/uuid_details' do
  
  service_type = params['service_type']
  uuid_value = params['uuid_value'] # uuid_value = "bce946c6-e167-4b50-b145-1700eafa889b"
  response = []
  begin
    @cluster = Cassandra.cluster
    @sessionCass = @cluster.connect(KEYSPACE)
    @selectUuidStatement = @sessionCass.prepare(
      'SELECT * FROM octo.' + service_type + ' WHERE id=' + uuid_value
    )
    result = @sessionCass.execute(@selectUuidStatement)

    if result and result.size == 1
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

# Manage Clients
get '/clients_manage' do
  erb '<div class="page-header">Client Manage</div>'
end

# Notification Templates
get '/notification_templates' do
  erb '<div class="page-header">Notification Template</div>'
end