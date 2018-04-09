class PollContent
  include Sidekiq::Worker
  def perform
    while true
      poll_comments
      poll_submissions
    end
  end
  
  def poll_comments
    begin
      Poll.new.store_latest_comments
    rescue Mongo::Error::BulkWriteError
      print "."
    rescue OpenURI::HTTPError
      retry
    end
    sleep(1)
  end
  
  def poll_submissions
    begin
      Poll.new.store_latest_submissions
    rescue Mongo::Error::BulkWriteError
      print "."
    rescue OpenURI::HTTPError
      retry
    end
    sleep(1)
  end
end