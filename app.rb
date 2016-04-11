require 'rubygems'
require 'sinatra'
require "sinatra/config_file"
require 'securerandom'
require 'json'
require 'cassandra'
require 'net/http'
require 'uri'
require 'digest/sha1'

require 'cequel'
require 'octocore'

require_relative 'helper'
require_relative 'routes/clients'
require_relative 'routes/templates'
require_relative 'routes/uuid_track'
require_relative 'routes/analytics'
require_relative 'routes/plugins'

register Sinatra::ConfigFile

config_file 'config/config.yml'

helpers Dashboard::Helpers

register Dashboard::Client
register Dashboard::Templates
register Dashboard::UuidTrack
register Dashboard::Analytics
register Dashboard::Plugins

Octo.connect_with_config_file(File.join(Dir.pwd, 'config', 'config.yml'))

configure do
  enable :sessions
end

before do
  pass if %w[login].include? request.path_info.split('/')[1]
  unless session[:identity] && validate_token(session[:identity], session[:session_token])
    halt erb(:login_form)
  end
end

# Root URL
# Display homepage
get '/' do
  erb :index
end

# Reuest for Login Page
# Display Login Form
get '/login' do
  erb :login_form
end

# Perform Login
post '/login' do
  username = params['username']
  password = params['password']
  begin
    res = fetch_consumer( username)
    if res.admin && validate_password( username, password)
      session[:identity] = username
      session[:session_token] = save_session(username)
      redirect to '/'
    else
      erb :login_form
    end
  rescue Exception => e
    erb :login_form
  end
end

# Perform Logout
get '/logout' do
  destroy_session( session[:identity])
  session.delete(:identity)
  session.delete(:session_token)
  redirect to('/login')
end