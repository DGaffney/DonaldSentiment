require 'sidekiq'
require 'time'
require 'sidekiq/api'
require 'csv'
require 'set'
require 'json'
require 'pry'
require 'redis'
Sidekiq.configure_server do |config|
#  config.redis = { url: 'redis://192.168.2.11:3770/0' }
end

Sidekiq.configure_client do |config|
#  config.redis = { url: 'redis://192.168.2.11:3770/0' }
end
require 'open3'
$redis = Redis.new(host: "localhost", port: 3770, timeout: 100000000000)
class DonaldExtractor
  include Sidekiq::Worker
  sidekiq_options queue: :donald_extractor
  def perform(filename, path="/net/data/pilling/raw_reddit_data/")
    `bzip2 -dck #{path}/#{filename} | jq -c 'select(.subreddit=="The_Donald")' > #{path}/../Donald/#{filename.gsub(".bz2", ".json")}`
  end

  def self.kickoff(path="/net/data/pilling/raw_reddit_data/")
    `ls #{path}`.split("\n").each do |file|
      year = file.split("_").last.split("-").first
      month = file.split("-").last.split(".").first
      time = Time.parse("#{year}-#{month}-01")
      self.perform_async(file) if time > Time.parse("2015-05-01")
    end
  end
end