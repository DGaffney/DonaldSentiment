class PollContent
  include Sidekiq::Worker
  def perform(data_type)
    if data_type == "comments"
      poll_comments
    else
      poll_submissions
    end
  end
  
  def poll_comments
    while true
      begin
        Poll.new.store_latest_comments
      rescue Mongo::Error::BulkWriteError
        print "."
      end
      sleep(1)
    end
  end
  
  def poll_submissions
    while true
      begin
        Poll.new.store_latest_submissions
      rescue Mongo::Error::BulkWriteError
        print "."
      end
      sleep(1)
    end
  end
end