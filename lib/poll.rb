class Poll
  def comment_url
    "https://api.pushshift.io/reddit/comment/search/?subreddit=The_Donald&limit=1000&after=#{Time.now.utc.to_i-60*5}&sort=asc&sort_type=created_utc"
  end

  def latest_comments
    JSON.parse(open(comment_url).read)["data"]
  end
  
  def store_latest_comments
    lc = latest_comments
    times = {}
    lc.each do |c|
      times[c["author"]] ||= []
      times[c["author"]] << c["created_utc"]
    end;false
    found_authors = Hash[$client[:reddit_authors].find({"author" => {"$in" => times.keys}}).to_a.collect{|x| [x["author"], x]}]
    lc.collect{|c| c["author"]}.counts.each do |author, count|
      if found_authors[author].nil?
        $client[:reddit_authors].insert_one({author: author, "first_comment_seen" => times[author].sort.first})
      end
      $client[:reddit_authors].update_one({author: author}, {"$inc" => {"comment_count" => count}})
      $client[:reddit_authors].update_one({author: author}, {"$set" => {"last_comment_seen" => times[author].sort.last}})
    end
    $client[:reddit_comments].insert_many(lc, ordered: false)
  end

  def submission_url
    "https://api.pushshift.io/reddit/submission/search/?subreddit=The_Donald&limit=1000&after=#{Time.now.utc.to_i-60*5}&sort=asc&sort_type=created_utc"
  end

  def latest_submissions
    JSON.parse(open(submission_url).read)["data"]
  end
  
  def subreddit_url
    "https://www.reddit.com/r/the_donald/about.json"
  end

  def latest_subreddit_info
    JSON.parse(open(subreddit_url).read)["data"]
  end

  def store_latest_subreddit_info
    latest = latest_subreddit_info
    $client[:reddit_subreddits].insert_one(latest)
  end

  def store_latest_submissions
    ls = latest_submissions
    times = {}
    ls.each do |s|
      times[s["author"]] ||= []
      times[s["author"]] << s["created_utc"]
    end;false
    found_authors = Hash[$client[:reddit_authors].find({"author" => {"$in" => times.keys}}).to_a.collect{|x| [x["author"], x]}]
    ls.collect{|s| s["author"]}.counts.each do |author, count|
      if found_authors[author].nil?
        $client[:reddit_authors].insert_one({author: author, "first_submission_seen" => times[author].sort.first})
      end
      $client[:reddit_authors].update_one({author: author}, {"$inc" => {"submission_count" => count}})
      $client[:reddit_authors].update_one({author: author}, {"$set" => {"last_submission_seen" => times[author].sort.last}})
    end
    ls.each do |submission|
      domain = URI.parse(submission["url"]).host rescue nil
      next if domain.nil?
      if $client[:domains].find(domain: domain).first.nil?
        $client[:domains].insert_one(AlexaRank.new.get_score(domain).merge(hit_count: 1))
      else
        $client[:domains].update_one({domain: domain}, {"$inc" => {hit_count: 1}})
      end
    end
    $client[:reddit_submissions].insert_many(ls, ordered: false)
  end
end

