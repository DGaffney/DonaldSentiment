require 'sinatra/base'

class Site < Sinatra::Base
  get "/api/ping.json" do
    return {"pong": "success"}.to_json
  end

  get "/api/latest/:content_type.json" do
    return Report.report(Time.now, params[:content_type]).sort_by{|k,v| k}.to_json
  end

  get "/api/at_time/:time.json" do
    return Report.report(Time.at(params[:time].to_i)).sort_by{|k,v| k}.to_json
  end
end