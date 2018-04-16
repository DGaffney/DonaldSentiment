class Fixnum
  def nan?
    return false
  end
end
class Report
  attr_accessor :raw_data
  def self.latest
    $client[:stats].find(time: Time.at(TimeDistances.time_ten_minute(Time.now)).utc).first
  end

  def self.current
    $client[:stats].find(time: Time.at(TimeDistances.time_ten_minute(Time.now)).utc).first
  end
  
  def self.previous
    $client[:stats].find(time: Time.at(TimeDistances.time_ten_minute_previous(Time.now)).utc).first
  end
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
      submission["updated_info"] << {"admin_deleted"=>false, "user_deleted"=>false, "ups"=>0, "gilded"=>0, "edited"=>false, "delay"=>0}
      sorted_updates = (submission["updated_info"]||[]).sort_by{|x| x["delay"]}
      latest_update = sorted_updates.last || {}
      scored = sorted_updates.collect{|x| [x["ups"], x["delay"]]}.reject{|x| x[1] > 1800}
      admin_deleted_at = sorted_updates.select{|x| x["admin_deleted"]}.first["delay"] rescue nil
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

  def initialize(time=Time.now)
    @raw_data = {
      comments: time_partition(time, format_comments(db_query(time, :reddit_comments))),
      submissions: time_partition(time, format_submissions(db_query(time, :reddit_submissions))),
      authors: db_query(time, :reddit_authors).to_a,
      subreddit_counts: time_partition(time, db_query(time, :subreddit_counts)),
      domain_map: get_domains(time, db_query(time, :reddit_submissions))
      };false
  end
  
  def stats
    {
      comments: get_comment_stats,
      submissions: get_submission_stats,
      subreddit_counts: get_subreddit_count_stats,
      domains: @raw_data[:domain_map]
    }
  end
  def hydrate_referenced_objs(references)
    hydrated = {}
    references[:map].each do |refkey, time_slices|
      hydrated[refkey] ||= {}
      time_slices.each do |range, ids|
        hydrated[refkey][range] = ids.collect{|id| references[:references][id]}
      end
    end;false
    hydrated
  end

  def get_comment_stats
    hydrate_referenced_objs(@raw_data[:comments]).collect{|k,v| Hash[k,Hash[v.collect{|vv, vvv| [vv, Hash[common_stats(vvv)]]}]]}
  end

  def get_submission_stats
    hydrate_referenced_objs(@raw_data[:submissions]).collect{|k,v| Hash[k,Hash[v.collect{|vv, vvv| [vv, Hash[common_stats(vvv)]]}]]}
  end
  
  def get_subreddit_count_stats
    @raw_data[:subreddit_counts].collect{|k,v| Hash[k,Hash[v.collect{|vv, vvv| [vv, Hash[subreddit_count_stats(vvv)]]}]]}
  end

  def collection_field_query(collection)
    {reddit_comments: :created_utc,
    reddit_submissions: :created_utc,
    reddit_authors: [:last_submission_seen, :last_comment_seen],
    subreddit_counts: :time}[collection]
  end

  def projections(collection)
    Hash[{reddit_comments: [:id, :created_utc, :author, :ups, :parent_id, :id, :link_id, :body, :updated_info],
    reddit_submissions: [:id, :created_utc, :author, :ups, :url, :id, :link_id, :body, :updated_info],
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
    Hash[$client[:domains].find(domain: {"$in" => hosts.keys}).collect{|x| [x["domain"], x.merge("current_count" => hosts[x["domain"]])]}].to_a
  end
  
  def self.backfill(latest=Time.at(TimeDistances.time_ten_minute(Time.now)).utc, dist=60*60*24*7, window=60*10)
    cursor = latest
    while latest-dist < cursor
      CreateReport.perform_async(cursor.utc)
      print "."
      cursor -= window
    end
  end
end
#t = Time.now;gg = Report.snapshot;tt = Time.now;false
#Time.now.strftime("%Y-%m-%d")
#Report.backfill