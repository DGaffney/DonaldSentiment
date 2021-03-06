require 'sinatra'
require 'dgaff'
require 'pry'
require 'open-uri'
require 'json'
require 'redis'
require 'time'
require 'mongo'
require 'sidekiq'
require 'uri'
require 'crack'
require 'sidekiq-cron'
SETTINGS = JSON.parse(File.read("settings.json"))
$client = Mongo::Client.new([ SETTINGS["db_url"] ], :database => SETTINGS["db"], :max_pool_size => 100, :wait_queue_timeout => 3000000, :connect_timeout => 3000000, :socket_timeout => 3000000)
Mongo::Logger.logger.level = Logger::FATAL
$client[:reddit_authors].indexes.create_one({ author: 1 }, unique: true)
$client[:domains].indexes.create_one({ domain: 1 }, unique: true)
$client[:reddit_comments].indexes.create_one({ id: 1 }, unique: true)
$client[:reddit_submissions].indexes.create_one({ id: 1 }, unique: true)
$client[:subreddit_counts].indexes.create_one({created_utc: 1})
$client[:subreddit_counts].indexes.create_one({created_utc: -1})
$client[:reddit_comments].indexes.create_one({ created_utc: 1 })
$client[:reddit_submissions].indexes.create_one({ created_utc: 1 })
$client[:reddit_comments].indexes.create_one({ created_utc: -1 })
$client[:reddit_submissions].indexes.create_one({ created_utc: -1 })
$client[:stats].indexes.create_one({ time: -1 })
$redis = Redis.new

Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/tasks/*.rb'].each {|file| require file }
def store_export
  f = File.open("export.json", "w")
  f.write({submissions: $client[:reddit_submissions].find.to_a, comments: $client[:reddit_comments].find.to_a}.to_json)
  f.close
  f = File.open("corpus.txt", "w")
  $client[:reddit_comments].find.to_a.each do |x|
    f.write(x["body"].gsub("\n", " ")+"\n")
  end;false
  f.close
end

#$client[:stats].find.each do |obj|
#obj["content"]["submissions"]["references"].collect{|k,v| [k, (v.to_json rescue nil)]}.select{|x| x[1] == nil}
#$client[:stats].update_one({_id: obj["_id"]}, {"$set" => {"time" => Time.at(TimeDistances.time_ten_minute(obj["time"])).utc}})
#end;false

#i = 0
#$client[:reddit_submissions].find.each do |submission|
#  UpdateContent.update_info_for_existing(submission, :reddit_submissions)
#  print i if i % 10000 == 0
#  i += 1
#end;false
#
#i = 0
#$client[:reddit_comments].find.each do |submission|
#  UpdateContent.update_info_for_existing(submission, :reddit_comments)
#  print i if i % 10000 == 0
#  i += 1
#end;false