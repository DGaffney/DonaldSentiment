require 'pry'
require 'open-uri'
require 'json'
require 'redis'
require 'time'
require 'mongo'
require 'sidekiq'
SETTINGS = JSON.parse(File.read("settings.json"))
$client = Mongo::Client.new([ SETTINGS["db_url"] ], :database => SETTINGS["db"], :max_pool_size => 100, :wait_queue_timeout => 3000000, :connect_timeout => 3000000, :socket_timeout => 3000000)
Mongo::Logger.logger.level = Logger::FATAL
$client[:reddit_comments].indexes.create_one({ id: 1 }, unique: true)
$client[:reddit_submissions].indexes.create_one({ id: 1 }, unique: true)
$client[:reddit_comments].indexes.create_one({ created_utc: 1 })
$client[:reddit_submissions].indexes.create_one({ created_utc: 1 })
$client[:reddit_comments].indexes.create_one({ created_utc: -1 })
$client[:reddit_submissions].indexes.create_one({ created_utc: -1 })
$redis = Redis.new
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/tasks/*.rb'].each {|file| require file }