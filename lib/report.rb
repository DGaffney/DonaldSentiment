class Fixnum
  def nan?
    return false
  end
end
class Report
  attr_accessor :raw_data
  def self.prev_month_query(time)
    {"$or" => TimeDistances.same_time_in_previous_month(time).collect{|x| {"time" => Hash[["$lte", "$gte"].zip(x)]}}}
  end
  
  def self.prev_days_query(time)
    {"$or" => TimeDistances.same_time_in_previous_days(time).collect{|x| {"time" => Hash[["$lte", "$gte"].zip(x)]}}}
  end
  
  def self.report_projection(content_type)
    if content_type == "comments"
      projection = {"time" => 1, "content.stats.comments" => 1}
    elsif content_type == "submissions"
      projection = {"time" => 1, "content.stats.submissions" => 1}
    elsif content_type == "subscribers"
      projection = {"time" => 1, "content.stats.subreddit_counts" => 1}
    elsif content_type == "domains"
      projection = {"time" => 1, "content.stats.domains" => 1}
    end
    projection
  end

  def self.reference_points(stats_obj, time, content_type)
    {prev_month: $client[:stats].find(self.prev_month_query(time)).projection(self.report_projection(content_type)).to_a, prev_day: $client[:stats].find(self.prev_days_query(time)).projection(self.report_projection(content_type)).to_a}
  end

  def self.report(time=Time.now, content_type="comments", reduction=false)
    results = {}
    time_int = TimeDistances.time_ten_minute(time)
    if reduction
      $client[:stats].find(time: {"$gte" => time_int-60*60*24, "$lte" => time_int}).projection(self.report_projection(content_type)).each do |time_point|
        results[time_point["time"]] = {observation: time_point, reference: self.reference_points(time_point, time_point["time"], content_type)}
      end
    else
      $client[:stats].find(time: {"$gte" => time_int-60*60*24, "$lte" => time_int}).each do |time_point|
        results[time_point["time"]] = {observation: time_point, reference: self.reference_points(time_point, time_int, content_type)}
      end
    end
    return results
  end

  def time_series
    ["10_minutes_past_day", "24_hours", "hour_days_past_month", "hours_in_week"]
  end

  def metrics
    ["karma_admin_deletion", "upvotes", "submissions", "comments", "submissions_authors", "comments_authors"]
  end

  def subreddit_count_analyses
    [:subscribers, :active_users, :active_percent]
  end

  def subreddit_count_stats(objects)
    Hash[subreddit_count_analyses.collect{|k| [k, self.send(k, objects)]}]
  end

  def subscribers(objects)
    objects.collect{|obj| obj["subscribers"]}
  end

  def active_users(objects)
    objects.collect{|obj| obj["active_users"]}
  end

  def active_percent(objects)
    objects.collect{|obj| obj["active_users"].to_f/obj["subscribers"]}
  end

  def common_analyses
    [:count, :distinct_count, :author_deleted_count, :admin_deleted_count, :author_deleted_time, :admin_deleted_time, :distinct_author_deleted_count, :distinct_admin_deleted_count, :author_karma_deletion, :admin_karma_deletion, :author_karma_deletion_speed, :admin_karma_deletion_speed]
  end
  
  def common_stats(objects)
    Hash[common_analyses.collect{|k| [k, self.send(k, objects)]}.collect{|k,v| [k, v.nan? ? 0 : v]}]
  end

  def count(objects)
    return objects.count
  end

  def distinct_count(objects)
    return objects.collect{|obj| obj[:author]}.uniq.count
  end

  def author_deleted_count(objects)
    return objects.select{|obj| !obj[:user_deleted_at].nil?}.count
  end

  def admin_deleted_count(objects)
    return objects.select{|obj| !obj[:admin_deleted_at].nil?}.count
  end

  def author_deleted_time(objects)
    return objects.collect{|obj| obj[:user_deleted_at]}.compact.average
  end

  def admin_deleted_time(objects)
    return objects.collect{|obj| obj[:admin_deleted_at]}.compact.average
  end

  def distinct_author_deleted_count(objects)
    return objects.select{|obj| !obj[:user_deleted_at].nil?}.collect{|obj| obj[:author]}.uniq.count
  end

  def distinct_admin_deleted_count(objects)
    return objects.select{|obj| !obj[:admin_deleted_at].nil?}.collect{|obj| obj[:author]}.uniq.count
  end

  #use abs val instead of raw score to account for net "disruptance" of deletions
  def author_karma_deletion(objects)
    return objects.select{|obj| !obj[:user_deleted_at].nil?}.collect{|obj| obj[:net_karma].abs}.sum
  end

  def admin_karma_deletion(objects)
    return objects.select{|obj| !obj[:admin_deleted_at].nil?}.collect{|obj| obj[:net_karma].abs}.sum
  end

  def author_karma_deletion_speed(objects)
    return objects.select{|obj| !obj[:user_deleted_at].nil?}.collect{|obj| obj[:net_karma].abs/obj[:user_deleted_at].to_f}.average
  end

  def admin_karma_deletion_speed(objects)
    return objects.select{|obj| !obj[:admin_deleted_at].nil?}.collect{|obj| obj[:net_karma].abs/obj[:admin_deleted_at].to_f}.average
  end

  def format_comments(query)
    objects = []
    query.collect do |comment|
      sorted_updates = (comment["updated_info"]||[]).sort_by{|x| x["delay"]}
      latest_update = sorted_updates.last || {}
      scored = sorted_updates.collect{|x| [x["ups"], x["delay"]]}.reject{|x| x[1] > 1800}
      admin_deleted_at = sorted_updates.select{|x| x["admin_deleted"]}.first["delay"] rescue nil
      user_deleted_at = sorted_updates.select{|x| x["user_deleted"]}.first["delay"] rescue nil
      toplevel = comment["parent_id"].include?("t3_") ? true : false
      up_rate = (scored[1..-1]||[]).each_with_index.collect{|r, i| (r[0]-scored[i][0])/(r[1]-scored[i][1]).to_f}.average
      objects << {id: comment["id"], net_karma: latest_update["ups"].to_f, time: comment["created_utc"], up_rate: (up_rate.nan? || !up_rate.finite? ? 0 : up_rate), admin_deleted_at: admin_deleted_at, user_deleted_at: user_deleted_at, author: comment["author"], toplevel: toplevel, body: comment["body"]}
    end
    objects
  end

  def format_submissions(query)
    objects = []
    query.collect do |submission|
      submission["updated_info"] ||= []
      submission["updated_info"] << {"admin_deleted"=>false, "user_deleted"=>false, "ups"=>0, "gilded"=>0, "edited"=>false, "delay"=>0} if submission["updated_info"].empty?
      sorted_updates = (submission["updated_info"]||[]).sort_by{|x| x["delay"]}
      latest_update = sorted_updates.last || {}
      scored = sorted_updates.collect{|x| [x["ups"]||0, x["delay"]||0]}.reject{|x| x[1] > 1800}
      admin_deleted_at = sorted_updates.select{|x| x["admin_deleted"] || x["shadow_deleted"]}.first["delay"] rescue nil
      user_deleted_at = sorted_updates.select{|x| x["user_deleted"]}.first["delay"] rescue nil
      domain = URI.parse(submission["url"]).host rescue nil
      up_rate = (scored[1..-1]||[]).each_with_index.collect{|r, i| (r[0]-scored[i][0])/(r[1]-scored[i][1]).to_f}.average
      objects << {id: submission["id"], delay_count: scored.count, net_karma: latest_update["ups"].to_f, time: submission["created_utc"], up_rate: (up_rate.nan? || !up_rate.finite? ? 0 : up_rate), admin_deleted_at: admin_deleted_at, user_deleted_at: user_deleted_at, author: submission["author"], domain: domain}
      objects[-1][:up_rate] = 0 if objects[-1][:up_rate].nan?
    end
#    csv = CSV.open("counts.csv", "w")
#    objects.select{|x| x[:net_karma] != 0 && x[:delay_count] > 1}.each do |row|
#      csv << [Math.log(row[:net_karma]), Math.log(row[:up_rate])]
#    end;false
#    csv.close
    objects
  end

  def self.snapshot(time=Time.now)
    obj = self.new(time)
    obj.raw_data.merge({stats: obj.stats})
  end
  
  def time_partition(time, objects)
    time_map = TimeDistances.time_bands(time)
    time_mapped_objects = {}
    object_references = {}
    objects.each do |object|
      time_map.each do |time_title, ranges|
        time_mapped_objects[time_title] ||= {}
        ranges.each do |range|
          time_mapped_objects[time_title][range.join(",")] ||= []
          if object.keys.include?(:id)
            time_mapped_objects[time_title][range.join(",")] << object[:id] if object[:time] <= range[0] && object[:time] > range[1]
            object_references[object[:id]] = object
          else
            time_mapped_objects[time_title][range.join(",")] << object if object[:time] <= range[0] && object[:time] > range[1]
          end
        end
      end
    end
    if object_references.empty?
      return time_mapped_objects
    else
      return {map: time_mapped_objects, references: object_references}
    end
  end

  def initialize(time=Time.at(TimeDistances.time_ten_minute(Time.now)).utc.to_i)
    range = [time, time-600]
    @raw_data = {
      start_time: range.last,
      end_time: range.first,
      comments: format_comments(db_query(time, :reddit_comments)),
      submissions: format_submissions(db_query(time, :reddit_submissions)),
      authors: db_query(time, :reddit_authors).to_a,
      subreddit_counts: {raw: db_query(time, :subreddit_counts).to_a.first, diff: subscriber_count_diff(subscriber_query(time, :subreddit_counts), subscriber_query(time-3600, :subreddit_counts))},
      domain_map: get_domains(time, db_query(time, :reddit_submissions))
      };false
  end
  
  def subscriber_count_diff(cur_count, prev_count)
    active_pct = (cur_count["active_users"].to_f/cur_count["subscribers"]-prev_count["active_users"].to_f/prev_count["subscribers"])
    {subscriber_count: (cur_count["subscribers"]-prev_count["subscribers"])/((cur_count["time"]-prev_count["time"])/60/60.0),
    active_count: (cur_count["active_users"]-prev_count["active_users"])/((cur_count["time"]-prev_count["time"])/60/60.0),
    active_pct: ((active_pct.nan? || !active_pct.finite?) ? 0 : active_pct)}
  end

  def stats
    {
      comments: get_comment_stats,
      submissions: get_submission_stats,
      subreddit_counts: get_subreddit_count_stats,
      domains: @raw_data[:domain_map]
    }
  end

  def get_comment_stats
    common_stats(@raw_data[:comments])
  end

  def get_submission_stats
    common_stats(@raw_data[:submissions])
  end
  
  def get_subreddit_count_stats
    @raw_data[:subreddit_counts]
  end

  def collection_field_query(collection)
    {reddit_comments: :created_utc,
    reddit_submissions: :created_utc,
    reddit_authors: [:last_submission_seen, :last_comment_seen],
    subreddit_counts: :time}[collection]
  end

  def projections(collection)
    Hash[{reddit_comments: [:id, :created_utc, :author, :ups, :parent_id, :id, :link_id, :body, :updated_info],
    reddit_submissions: [:id, :created_utc, :author, :ups, :url, :id, :link_id, :body, :updated_info, :num_comments, :url],
    reddit_authors: [:author, :comment_count, :last_comment_seen, :first_comment_seen, :submission_count, :last_submission_seen, :first_submission_seen],
    subreddit_counts: [:time, :subscribers, :active_users]}[collection].collect{|k| [k, 1]}]
  end

  def subscriber_query(time, collection)
    query = {collection_field_query(collection) => {"$lte" => time}}
    $client[collection].find(query, :sort => {'time' => -1}).projection(projections(collection)).first
  end

  def db_query(time, collection)
    range = [time, time-600]
    if collection_field_query(collection).class == Array
      query = {"$or" => collection_field_query(collection).collect{|c| {c => {"$lte" => range.first, "$gte" => range.last}}}}
    else
      query = {collection_field_query(collection) => {"$lte" => range.first, "$gte" => range.last}}
    end
    $client[collection].find(query).projection(projections(collection))
  end

  def get_domains(time, queries)
    host_counts = {}
    host_num_counts = {}
    host_karma_counts = {}
    db_query(time, :reddit_submissions).each do |submission|
      host = URI.parse(submission["url"]).host rescue nil
      next if host.nil?
      host_counts[host] ||= 0
      host_num_counts[host] ||= 0
      host_karma_counts[host] ||= 0
      host_counts[host] += 1
      host_num_counts[host] += ((submission["updated_info"].sort_by{|k| k["delay"]}.last["num_comments"] rescue 0)||0)
      host_karma_counts[host] += ((submission["updated_info"].sort_by{|k| k["delay"]}.last["ups"] rescue 0)||0)
    end
    Hash[$client[:domains].find(domain: {"$in" => host_counts.keys}).collect{|x| [x["domain"], x.merge("current_count" => host_counts[x["domain"]], "num_comment_count" => host_num_counts[x["domain"]], "karma_count" => host_karma_counts[x["domain"]])]}].to_a
  end
 
  def self.backfill(latest=Time.at(TimeDistances.time_ten_minute(Time.now)).utc.to_i, dist=60*60*24*7, window=60*10)
    cursor = latest
    while latest-dist < cursor
      CreateReport.perform_async(cursor)
      print "."
      cursor -= window
    end
  end
end
#t = Time.now;gg = Report.snapshot;tt = Time.now;false
#Time.now.strftime("%Y-%m-%d")
#$client[:stats].drop
#$client[:stats].indexes.create_one({ time: -1 })
#Report.backfill
#Report.snapshot