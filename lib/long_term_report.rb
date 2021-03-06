class LongTermReport
  include Sidekiq::Worker
  def self.report
    full_stats = Hash[$client[:day_stats].find.collect{|x| [Time.at(x["start_time"]), x]}];false
    stats_with_reference = {}
    full_stats.each do |date, data|
      stats_with_reference[date] = {observed: data, reference: full_stats[date-60*60*24*7]}
    end
    Hash[stats_with_reference.sort_by{|k,v| k}]
#    latest = full_stats.keys.sort.last
#    missing = []
#    while latest > full_stats.keys.sort.first
#      missing << latest if !full_stats.keys.include?(latest)
#      latest -= 24*60*60
#    end
  end

  def perform(day=(Time.now.utc-60*60*12).to_s)
    start_time_int = Time.parse(Time.parse(day.to_s).strftime("%Y-%m-%d 00:00:00 +0000")).utc.to_i
    end_time_int = Time.parse(Time.parse(day.to_s).strftime("%Y-%m-%d 23:59:59 +0000")).utc.to_i
    comments = Report.new.format_comments($client[:reddit_comments].find(created_utc: {"$gte" => start_time_int, "$lte" => end_time_int}))
    submissions = Report.new.format_submissions($client[:reddit_submissions].find(created_utc: {"$gte" => start_time_int, "$lte" => end_time_int}))
    subscriber_counts = $client[:subreddit_counts].find(time: {"$gte" => start_time_int, "$lte" => end_time_int}).to_a
    com_stats = Report.new.common_stats(comments)
    sub_stats = Report.new.common_stats(submissions)
    sorted_subscriber_counts = subscriber_counts.sort_by{|x| x["time"]}.reject{|x| x["subscribers"] == 0}
    avg_active_pct = sorted_subscriber_counts.collect{|x| x["active_users"].to_f/x["subscribers"]}.reject(&:nan?).select(&:finite?).average
    avg_active_pct = 0.0 if avg_active_pct.nan? || !avg_active_pct.finite?
    subscriber_counts = (sorted_subscriber_counts[1..-1]||[]).each_with_index.collect{|s, i| Report.new.subscriber_count_diff(s, sorted_subscriber_counts[i])}.collect{|x| x[:subscriber_count]}.reject(&:nan?).select(&:finite?).average
    subscriber_counts = 0.0 if subscriber_counts.nan? || !subscriber_counts.finite?
    mapped = {core_stats: Hash[com_stats.collect{|k,v| ["comments_"+k.to_s, v]}].merge(Hash[sub_stats.collect{|k,v| ["submissions_"+k.to_s, v]}]).merge("avg_active_pct" => avg_active_pct, "subscriber_counts" => subscriber_counts)}
    mapped[:url_stats] = domain_map(submissions)
    $client[:day_stats].insert_one(start_time: start_time_int, end_time: end_time_int, content: mapped)
  end
  
  def domain_map(submissions)
    host_counts = {}
    host_num_counts = {}
    host_karma_counts = {}
    submissions.each do |submission|
      host = submission[:domain]
      next if host.nil?
      host_counts[host] ||= 0
      host_num_counts[host] ||= 0
      host_karma_counts[host] ||= 0
      host_counts[host] += 1
      host_num_counts[host] += submission[:comment_count].to_f
      host_karma_counts[host] += submission[:net_karma].to_f
    end
    category_counts = {}
    categories = Hash[$client[:domains].find(domain: {"$in" => host_counts.keys}).projection(category: 1, domain: 1).collect{|x| [x["domain"], x["category"]||"uncategorized"]}]
    host_counts.keys.each do |domain|
      next if categories[domain].nil?
      category_counts[categories[domain]] ||= {count: host_counts[domain], num_comment_count: host_num_counts[domain], karma_count: host_karma_counts[domain]}
      category_counts[categories[domain]][:count] += host_counts[domain]
      category_counts[categories[domain]][:num_comment_count] += host_num_counts[domain]
      category_counts[categories[domain]][:karma_count] += host_karma_counts[domain]
    end
    category_counts
  end
  
  def self.kickoff(earliest_day = Time.at(1448990666))
    start_time = Time.parse(Time.parse((Time.now-60*60*24*2).to_s).strftime("%Y-%m-%d 00:00:00 +0000")).utc
    day_count = ((start_time-earliest_day)/(60*60*24)).to_i
    day_count.downto(2).each do |day_step|
      LongTermReport.perform_async(start_time-60*60*24*day_step)
    end
  end
end