require 'sinatra/base'

class Site < Sinatra::Base
  get '/' do
    erb :index
  end
end