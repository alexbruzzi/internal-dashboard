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

KEYSPACE = 'octo'

register Dashboard::Client
register Dashboard::Templates
register Dashboard::UuidTrack

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