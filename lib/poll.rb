class Poll
  def comment_url
    "https://api.pushshift.io/reddit/comment/search/?subreddit=The_Donald&limit=1000"
  end

  def latest_comments
    JSON.parse(open(comment_url).read)["data"]
  end
  
  def store_latest_comments
    lc = latest_comments
    binding.pry
    $client[:reddit_comments].insert_many(lc, ordered: false)
  end

  def submission_url
    "https://api.pushshift.io/reddit/submission/search/?subreddit=The_Donald&limit=1000"
  end

  def latest_submissions
    JSON.parse(open(submission_url).read)["data"]
  end
  
  def store_latest_submissions
    ls = latest_submissions
    $client[:reddit_submissions].insert_many(ls, ordered: false)
  end
end