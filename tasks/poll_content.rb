class PollContent
  include Sidekiq::Worker
  def perform(data_type))
    if data_type == "comments"
      poll_comments
    else
      poll_submissions
    end
  end
  
  def poll_comments
    while true
      store_latest_comments
      sleep(1)
    end
  end
  
  def poll_submissions
    while true
      store_latest_submissions
      sleep(1)
    end
  end
end