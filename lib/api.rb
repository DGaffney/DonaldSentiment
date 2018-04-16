require 'sinatra/base'

class Site < Sinatra::Base
  get "/api/ping.json" do
    return {"pong": "success"}.to_json
  end

  get "/api/latest.json" do
    return Report.latest.to_json
  end

  get "/api/current.json" do
    return Report.current.to_json
  end

  get "/api/previous.json" do
    return Report.latest.to_json
  end
end