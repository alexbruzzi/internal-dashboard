require 'rubygems'
require 'sinatra'
require 'securerandom'
require 'json'
require 'cassandra'
require 'net/http'
require 'uri'
require 'digest/sha1'

require 'octocore'

require_relative 'routes/clients'
require_relative 'routes/templates'
require_relative 'routes/uuid_track'
require_relative 'routes/analytics'
require_relative 'routes/plugins'

KONG_URL = 'http://127.0.0.1:8001/'

register Dashboard::Client
register Dashboard::Templates
register Dashboard::UuidTrack
register Dashboard::Analytics
register Dashboard::Plugins

Octo.connect_with_config_file(File.join(Dir.pwd, 'config', 'config.yml'))

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
  erb :index
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

# helper function to create plugin if not exist
public def create_ratelimiting_plugin(apikey, consumer_id)

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

  url = KONG_URL + 'apis/' + apikey.to_s + '/plugins/'

  response = add_plugin(url, header, payload)

  if response['id']
    return response['id']
  else
    return "Error"
  end

  return ""
end
# end helper method

# Fetch Consumers List
public def consumerlist()

  # Kong Request URL
  url = KONG_URL + 'consumers/'
  
  # Add Any Contraint for filtering
  # id, custom_id, username, size, offset
  payload = {}
  
  header = {
    'Content-Type' => "application/json"
  }

  begin
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host,uri.port)
    req = Net::HTTP::Get.new(uri.path, header) # GET Method

    req.body = "#{payload}"
    res = http.request(req)
    json_res = JSON.parse(res.body)
    return json_res['data']
  rescue Exception => e
    print e.to_s
  end
  return ""
end

# Add Plugin
public def add_plugin(url, header, payload) 
  begin
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host,uri.port)
    req = Net::HTTP::Post.new(uri.path, header) # POST Method

    req.body = "#{payload}"
    res = http.request(req)
    return JSON.parse(res.body)
  rescue Exception => e
    return e.to_s
  end
  return ""
end

# helper method to create a new client
public def create_consumer(username, custom_id)
  @payload = {
    "username" => username.to_s,
    "custom_id" => custom_id.to_s
  }.to_json
  url = KONG_URL + 'consumers/'

  begin
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host,uri.port)
    req = Net::HTTP::Post.new(uri.path, initheader = { 'Content-Type' => 'application/json'})

    req.body = "#{@payload}"
    res = http.request(req)

    response = JSON.parse(res.body)

    result = create_keyauth(response["username"])

    return result
  rescue Exception => e
    print e.to_s
    return "Error"
  end
return ""
end
# end helper method

# helper method to create keyauth
public def create_keyauth(username)

  begin
    @payload = {
      "key" => generate_key()
    }.to_json

    url = KONG_URL + 'consumers/'+ username +'/key-auth'
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host,uri.port)
    req = Net::HTTP::Post.new(uri.path, initheader = { 'Content-Type' => 'application/json'})

    req.body = "#{@payload}"
    res = http.request(req)
    response = JSON.parse(res.body)
    return response["consumer_id"].to_s
  rescue Exception => e
    print e.to_s
  end
return ""
end
# end helper method

# helper function to generate Key for KeyAuth
public def generate_key()
  # Self Generate
  # Leave Blank to automatically generate Key
return ""
end
# end helper method