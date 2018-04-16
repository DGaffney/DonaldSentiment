require 'sinatra/base'

class Site < Sinatra::Base
  get "/latest.json" do
    return Report.latest.to_json
  end

  get "/current.json" do
    return Report.current.to_json
  end

  get "/previous.json" do
    return Report.latest.to_json
  end
end