require 'sinatra/base'

class Site < Sinatra::Base

  get '/' do
  if params[:timestamp].nil?
    @time = Time.now.to_i
  else
    @time = params[:timestamp]
  end

    erb :index
  end
end