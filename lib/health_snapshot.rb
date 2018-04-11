class HealthSnapshot
  def self.snapshot(start_time, width=60*60)
    comments = $client[:reddit_comments].find(created_utc: {"$gte" => start_time.utc.to_i, "$lte" => start_time.utc.to_i+width})
    submissions = $client[:reddit_submissions].find(created_utc: {"$gte" => start_time.utc.to_i, "$lte" => start_time.utc.to_i+width})
    row = {}
    self.datapoints.each do |datapoint|
      row[datapoint] = self.send(datapoint, comments, submissions, row)
    end
    row
  end
  
  def self.datapoints
    ["comment_count", "submission_count", "reciprocal_interactions", "distinct_author_comment_count", "distinct_author_submission_count", "posting_user_count"]
  end
  
  def self.posting_user_count(comments, submissions, row) 
    return (comments.to_a.collect{|x| x["author"]}|submissions.to_a.collect{|x| x["author"]}).count
  end

  def self.reciprocal_interactions
    interaction_tree = {}
    edges = []
    comments.each do |comment|
      collection = comment["parent_id"].include?("t1_") ? :reddit_comments : :reddit_submissions
      parent = $client[collection].find(id: comment["parent_id"].split("_").last).first
      if parent
        interaction_tree[parent["author"]] ||= []
        interaction_tree[parent["author"]] << comment["author"]
        edges << [parent["author"], comment["author"]].sort
      end
    end
    edges.counts.select{|k,v| v > 1}.count/edges.count.to_f
  end

  def self.submission_count(comments, submissions, row) 
    return submissions.count
  end

  def self.comment_count(comments, submissions, row) 
    return comments.count
  end

  def self.distinct_author_comment_count(comments, submissions, row) 
    return (comments.to_a.collect{|x| x["author"]}).uniq.count
  end

  def self.distinct_author_submission_count(comments, submissions, row) 
    return (submissions.to_a.collect{|x| x["author"]}).uniq.count
  end
  
  def self.internal_comment_links_subreddits(comments, submissions, row) 
    return comments.select{|x| x["body"].include?("/r/The_Donald")}.count
  end
  
  def self.external_comment_links_subreddits(comments, submissions, row) 
    return comments.select{|x| x["body"].include?("/r/")}.count
  end

  def self.external_comment_links_internet(comments, submissions, row) 
    return comments.select{|x| x["body"].include?("http")}.count
  end
  
  def self.external_comment_links_internet(comments, submissions, row) 
    return comments.select{|x| x["body"].include?("http")}.count
  end
  
end


#submissions = $client[:reddit_submissions].find.to_a;false
#submissions.collect{|x| URI.parse(x["url"]).host rescue nil}.counts