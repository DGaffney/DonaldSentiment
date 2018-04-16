require 'sinatra/base'
set :root, File.join(File.dirname(__FILE__), '../views/')
# sets the view directory correctly
set :views, Proc.new { File.join(root, "views") } 

class Site < Sinatra::Base

  get '/' do
    erb :"../index"
  end
end