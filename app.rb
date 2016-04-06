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

  client_list = consumerlist()
  client_list.each do |r|
    if params['username'] == r['username'].to_s
      key = Digest::SHA1.hexdigest(params['password'] + r['consumer_id'].to_s)
      if key == r['password'].to_s
        session[:identity] = params['username']
        redirect to '/'
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

# Fetch Consumers List
public def consumerlist()

  begin
    url = 'consumers/'
    
    # Add Any Contraint for filtering
    # id, custom_id, username, size, offset
    payload = {}
    
    header = {
      'Content-Type' => "application/json"
    }

    response = kong_request(url, "GET", header, payload)
    return response['data']
  rescue Exception => e
    print e.to_s
  end
  return ""
end

# helper method to create a new client
public def create_consumer(username, custom_id)
    
  begin
    url = 'consumers/'
    payload = {
      "username" => username.to_s,
      "custom_id" => custom_id.to_s
    }.to_json
    header = {
      'Content-Type' => 'application/json'
    }

    response = kong_request(url, "POST", header, payload)

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
    url = 'consumers/'+ username +'/key-auth'
    payload = {
      "key" => generate_key()
    }.to_json
    header = {
      'Content-Type' => 'application/json'
    }

    response = kong_request(url, "POST", header, payload)
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

# Any type of request to kong
# param - url - method ['GET', 'POST', 'PUT', 'PATCH'] - header (hash) - payload (json)
public def kong_request(url, method, header, payload)
  
  begin
    uri = URI.parse(KONG_URL + url)
    http = Net::HTTP.new(uri.host,uri.port)
    case method
    when "GET"
      req = Net::HTTP::Post.new(uri.path, header) # POST Method
    when "POST"
      req = Net::HTTP::Post.new(uri.path, header) # POST Method
    when "PUT"
      req = Net::HTTP::Put.new(uri.path, header) # POST Method
    when "PATCH"
      req = Net::HTTP::Patch.new(uri.path, header) # POST Method
    else
      # Default Case
    end

    req.body = "#{payload}"
    res = http.request(req)
    return JSON.parse(res.body)
  rescue Exception => e
    return e.to_s
  end
  return ""
end