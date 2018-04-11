class Report
  def time_series
    ["10_minutes_past_day", "24_hours", "hour_days_past_month", "hours_in_week"]
  end

  def time_series_titles
    ["24 Hour Detailed", "24 Hour", "Same Time in Past Month", "Same Time in past Week "]
  end

  def subsets
    ["top", "full", "long_term"]
  end

  def metrics
    ["karma_admin_deletion", "upvotes", "submissions", "comments", "submissions_authors", "comments_authors"]
  end

  def format_comments(query)
    objects = []
    query.collect do |comment|
      sorted_updates = comment["updated_info"].sort_by{|x| x["delay"]}
      latest_update = sorted_updates.last || {}
      admin_deleted_at = sorted_updates.select{|x| x["admin_deleted"]}.first["delay"] rescue nil
      user_deleted_at = sorted_updates.select{|x| x["user_deleted"]}.first["delay"] rescue nil
      toplevel = comment["parent_id"].include?("t3_") ? true : false
      objects << {time: comment["created_utc"], up_rate: latest_update["ups"].to_f/(latest_update["delay"]||1).to_f, admin_deleted_at: admin_deleted_at, user_deleted_at: user_deleted_at, author: comment["author"], toplevel: toplevel, body: comment["body"]}
    end
  end

  def format_submissions(query)
    objects = []
    query.collect do |submission|
      sorted_updates = submission["updated_info"].sort_by{|x| x["delay"]}
      latest_update = sorted_updates.last || {}
      admin_deleted_at = sorted_updates.select{|x| x["admin_deleted"]}.first["delay"] rescue nil
      user_deleted_at = sorted_updates.select{|x| x["user_deleted"]}.first["delay"] rescue nil
      domain = URI.parse(submission["url"]).host rescue nil
      objects << {net_karma: latest_update["ups"].to_f, time: submission["created_utc"], up_rate: latest_update["ups"].to_f/(latest_update["delay"]||1).to_f, admin_deleted_at: admin_deleted_at, user_deleted_at: user_deleted_at, author: submission["author"], body: submission["body"], domain: domain}
    end
  end

  def time_partition(time, objects)
    time_map = TimeDistances.time_bands(time)
    time_mapped_objects = {}
    objects.each do |object|
      time_map.each do |time_title, ranges|
        time_mapped_objects[time_title] ||= {}
        ranges.each do |range|
          time_mapped_objects[time_title][range] ||= []
            time_mapped_objects[time_title][range] << object if object[:time] <= range[0] && object[:time] > range[1]
        end
      end
    end;false
  end
  t = Time.now
gz =   time_partition(time, format_comments(db_query(time, :reddit_comments)));false
tt = Time.now
puts tt-t
  def initialize(time=Time.now)
    raw_data = {
      comments: time_partition(time, format_comments(db_query(time, :reddit_comments))),
      submissions: time_partition(time, format_comments(db_query(time, :reddit_submissions))),
      authors: db_query(time, :reddit_authors),
      subreddit_counts: db_query(time, :subreddit_counts),
      domain_map: get_domains(time, queries)
    }
    
  end

  def collection_field_query(collection)
    {reddit_comments: :created_utc,
    reddit_submissions: :created_utc,
    reddit_authors: [:last_submission_seen, :last_comment_seen],
    subreddit_counts: :time}[collection]
  end

  def projections(collection)
    Hash[{reddit_comments: [:created_utc, :author, :ups, :parent_id, :id, :link_id, :body, :updated_info],
    reddit_submissions: [:created_utc, :author, :ups, :url, :id, :link_id, :body, :updated_info],
    reddit_authors: [:author, :comment_count, :last_comment_seen, :first_comment_seen, :submission_count, :last_submission_seen, :first_submission_seen],
    subreddit_counts: [:time, :subscribers, :active_users]}[collection].collect{|k| [k, 1]}]
  end

  def db_query(time, collection)
    time_distances = TimeDistances.time_queries(time)
    uniq_time_queries = []
    time_distances.values.each do |v|
      v.each do |vv|
        uniq_time_queries << vv
      end
    end
    queries = []
    if collection_field_query(collection).class == Array
      queries = {"$or" => uniq_time_queries.uniq.collect{|range| collection_field_query(collection).collect{|c| {c => {"$lte" => range.first, "$gte" => range.last}}}}.flatten}
    else
      queries = {"$or" => uniq_time_queries.uniq.collect{|range| {collection_field_query(collection) => {"$lte" => range.first, "$gte" => range.last}}}}
    end
    $client[collection].find(queries).projection(projections(collection))
  end

  def get_domains(time, queries)
    hosts = db_query(time, :reddit_submissions).projection(url: 1).to_a.collect{|x| x["url"]}.collect{|x| URI.parse(x).host rescue nil}.compact.counts
    Hash[$client[:domains].find(domain: {"$in" => hosts.keys}).collect{|x| [x["domain"], x.merge("current_count" => hosts[x["domain"]])]}]
  end
end