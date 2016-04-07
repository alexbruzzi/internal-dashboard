require 'rubygems'
require 'sinatra'
require 'securerandom'
require 'json'
require 'cassandra'
require 'net/http'
require 'uri'
require 'securerandom'
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
  result.rows.each do |r|
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

# helper method to create a new client
public def create_consumer(username, email, password)
  unless enterprise_name_exists?(username)

    # create enterprise
    e = Octo::Enterprise.new
    e.name = username
    e.save!

    # create its Authentication stuff
    auth = Octo::Authorization.new
    auth.enterprise = e
    auth.username = e.name
    auth.apikey = generate_key
    auth.email = email
    custom_id = e.id.to_s
    auth.password = generate_password(password, e.id.to_s)
    auth.save!

    method = "PUT"
    url = 'consumers/'
    payload = {
      username: e.name,
      custom_id: e.id.to_s
    }.to_json
    header = {
      'Content-Type' => 'application/json'
    }
    kong_request(url, method, header, payload)
    create_keyauth(e.name, auth.apikey)
  else
    return 'Not creating client as client name exists'
  end
  "success"
end

def enterprise_name_exists?(enterprise_name)
  Octo::Enterprise.all.select { |x| x.name == enterprise_name}.length > 0
end

def generate_password(password, consumer_id)
  Digest::SHA1.hexdigest(password + consumer_id)
end

def validate_password(password, consumer_id)
  
end

# helper method to create keyauth
def create_keyauth(username, keyauth_key)

  begin
    url = 'consumers/'+ username +'/key-auth'
    payload = {
      key: keyauth_key
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

def generate_key
  SecureRandom.hex
end

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