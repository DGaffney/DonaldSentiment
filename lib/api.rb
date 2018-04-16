require 'sinatra/base'

class Site < Sinatra::Base
  get "/api/ping.json" do
    return {"pong": "success"}.to_json
  end

  get "/api/latest.json" do
    return Report.report.to_json
  end
end