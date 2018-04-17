require 'sinatra/base'

class Site < Sinatra::Base

  get '/' do
    if params[:time].nil?
      @time = Time.now.to_i
    else
      @time = params[:time]
    end
    erb :index
  end
end