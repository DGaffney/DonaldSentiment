require 'sinatra/base'

class Site < Sinatra::Base

  get '/' do
    if params[:time].nil?
      @time = Time.now.to_i
      @distance = 1
    else
      @time = params[:time].to_i
      @distance = params[:distance].to_i
    end
    erb :index
  end

  get '/long_term' do
    erb :long_term
  end
end