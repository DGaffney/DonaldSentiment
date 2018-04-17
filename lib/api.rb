require 'sinatra/base'

class Site < Sinatra::Base
  get "/api/ping.json" do
    return {"pong": "success"}.to_json
  end

  get "/api/latest/:content_type/reduced.json" do
    params[:distance] = params[:distance].nil? ? 60*60*24 : params[:distance].to_i*60*60*24
    return {type: params[:content_type], data: Report.report(Time.now, params[:content_type], true, params[:distance]).sort_by{|k,v| k}}.to_json
  end

  get "/api/:timestamp/:content_type/reduced.json" do
    params[:distance] = params[:distance].nil? ? 60*60*24 : params[:distance].to_i*60*60*24
    if params[:timestamp] == "latest"
      return {type: params[:content_type], data: Report.report(Time.now, params[:content_type], true, params[:distance]).sort_by{|k,v| k}}.to_json
    else
      return {type: params[:content_type], data: Report.report(Time.at(params[:timestamp].to_i), params[:content_type], true, params[:distance]).sort_by{|k,v| k}}.to_json
    end
    
  end

  get "/api/latest/:content_type/full.json" do
    params[:distance] = params[:distance].nil? ? 60*60*24 : params[:distance].to_i*60*60*24
    return {type: params[:content_type], data: Report.report(Time.now, params[:content_type], false, params[:distance]).sort_by{|k,v| k}}.to_json
  end

  get "/api/:timestamp/:content_type/full.json" do
    params[:distance] = params[:distance].nil? ? 60*60*24 : params[:distance].to_i*60*60*24
    if params[:timestamp] == "latest"
      return {type: params[:content_type], data: Report.report(Time.now, params[:content_type], false, params[:distance]).sort_by{|k,v| k}}.to_json
    else
      return {type: params[:content_type], data: Report.report(Time.at(params[:timestamp].to_i), params[:content_type], false, params[:distance]).sort_by{|k,v| k}}.to_json
    end
  end
  
  get "/api/:model/:start_time.json" do
    model = {"submissions" => :reddit_submissions,
    "comments" => :reddit_comments,
    "subscribers" => :subreddit_counts}[params[:model]]
    time_param = {"submissions" => :created_utc,
    "comments" => :created_utc,
    "subscribers" => :time}[params[:model]]
    return $client[model].find({time_param => {"$gte" => params[:start_time].to_i}}, {:sort => ['created_utc',1]}).first(100).to_json
  end
end