require 'sinatra'
require 'rack'
load 'environment.rb'
set :root, File.dirname(__FILE__)
set :environment, :production
set :run, false
run Site
