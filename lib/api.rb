require 'sinatra/base'

class Site < Sinatra::Base
  get "/api/ping.json" do
    return {"pong": "success"}.to_json
  end

  get "/api/latest/:content_type/reduced.json" do
    return Report.report(Time.now, params[:content_type], true).sort_by{|k,v| k}.to_json
  end
end