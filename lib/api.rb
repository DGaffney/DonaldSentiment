require 'sinatra/base'

class Site < Sinatra::Base
  get "/api/ping.json" do
    return {"pong": "success"}.to_json
  end

  get "/api/latest/:content_type/reduced.json" do
    return {type: params[:content_type], data: Report.report(Time.now, params[:content_type], true).sort_by{|k,v| k}}.to_json
  end

  get "/api/:timestamp/:content_type/reduced.json" do
    if params[:timestamp] == "latest"
      return {type: params[:content_type], data: Report.report(Time.now, params[:content_type], true).sort_by{|k,v| k}}.to_json
    else
      return {type: params[:content_type], data: Report.report(Time.at(params[:timestamp].to_i), params[:content_type], true).sort_by{|k,v| k}}.to_json
    end
    
  end
end