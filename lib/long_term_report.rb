class LongTermReport
  include Sidekiq::Worker
  def perform(day)
    start_time_int = Time.parse(Time.parse(day.to_s).strftime("%Y-%m-%d 00:00:00 +0000")).utc.to_i
    end_time_int = Time.parse(Time.parse(day.to_s).strftime("%Y-%m-%d 23:59:59 +0000")).utc.to_i
    comments = Report.new.format_comments($client[:reddit_comments].find(created_utc: {"$gte" => start_time_int, "$lte" => end_time_int}))
    submissions = Report.new.format_submissions($client[:reddit_submissions].find(created_utc: {"$gte" => start_time_int, "$lte" => end_time_int}))
    subscriber_counts = $client[:subreddit_counts].find(time: {"$gte" => start_time_int, "$lte" => end_time_int}).to_a
    com_stats = Report.new.common_stats(comments)
    sub_stats = Report.new.common_stats(submissions)
    sorted_subscriber_counts = subscriber_counts.sort_by{|x| x["time"]}.reject{|x| x["subscribers"] == 0}
    avg_active_pct = sorted_subscriber_counts.collect{|x| x["active_users"].to_f/x["subscribers"]}.reject(&:nan?).select(&:finite?).average
    subscriber_counts = sorted_subscriber_counts[1..-1].each_with_index.collect{|s, i| Report.new.subscriber_count_diff(s, sorted_subscriber_counts[i])}.collect{|x| x[:subscriber_count]}.average
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
      host_num_counts[host] += submission[:comment_count]
      host_karma_counts[host] += submission[:net_karma]
    end
    Hash[$client[:domains].find(domain: {"$in" => host_counts.keys}).collect{|x| [x["domain"], x.merge("current_count" => host_counts[x["domain"]], "num_comment_count" => host_num_counts[x["domain"]], "karma_count" => host_karma_counts[x["domain"]])]}].to_a
  end
  
  def self.kickoff(earliest_day = Time.at(1448990666))
    start_time = Time.parse(Time.parse((Time.now-60*60*24*2).to_s).strftime("%Y-%m-%d 00:00:00 +0000")).utc
    day_count = ((start_time-earliest_day)/(60*60*24)).to_i
    day_count.downto(2).each do |day_step|
      LongTermReport.perform_async(start_time-60*60*24*day_step)
    end
  end
end