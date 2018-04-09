class Poll
  def comment_url
    "https://api.pushshift.io/reddit/comment/search/?subreddit=The_Donald&limit=1000"
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
      $client[:reddit_authors].update_one({author: author}, {"last_comment_seen" => times[author].sort.last})
    end
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
      $client[:reddit_authors].update_one({author: author}, {"last_submission_seen" => times[author].sort.last})
    end
    $client[:reddit_submissions].insert_many(ls, ordered: false)
  end
end
#$client[:reddit_comments].find.projection("author" => )