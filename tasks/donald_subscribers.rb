require 'json'
require 'nokogiri'
class DonaldSubscribers
  def run
    years = [2015,2016,2017,2018]
    old_results = results
    results = old_results.select{|x| x[1] != 0}
    #results = []
    years.each do |year|
      puts year
      #crawl_data = JSON.parse(open("https://web.archive.org/__wb/calendarcaptures?url=http%3A%2F%2Freddit.com%2Fr%2Fthe_donald&selected_year=#{year}").read)
      crawl_data = JSON.parse(`curl 'https://web.archive.org/__wb/calendarcaptures?url=http%3A%2F%2Freddit.com%2Fr%2Fthe_donald&selected_year=#{year}' -H 'Pragma: no-cache' -H 'DNT: 1' -H 'Accept-Encoding: gzip, deflate, br' -H 'Accept-Language: en-US,en;q=0.9' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' -H 'Cache-Control: no-cache' -H 'Cookie: s_pers=%20s_nr%3D1519182822143-New%7C1521774822143%3B%20s_lastvisit%3D1519182822148%7C1613790822148%3B%20s_vnum%3D1521774822159%2526vn%253D1%7C1521774822159%3B%20s_invisit%3Dtrue%7C1519184622159%3B%20gvp_p5%3Dwp%2520-%2520article%2520-%2520AR2010102106645%2520-%2520Lillian%2520McEwen%2520breaks%2520her%252019-year%2520silence%2520about%2520Justice%2520Clarence%2520Thomas%7C1519184622174%3B%20gvp_pn%3Dwp%2520-%2520article%2520-%2520AR2010102106645%2520-%2520Lillian%2520McEwen%2520breaks%2520her%252019-year%2520silence%2520about%2520Justice%2520Clarence%2520Thomas%7C1519184622181%3B; _ga=GA1.2.1805523511.1519247057; _recent_srs=t5_2u7i2' -H 'Connection: keep-alive' --compressed`)
      stamps = crawl_data.collect{|cd| cd.collect{|x| x.reject(&:nil?).reject(&:empty?).collect{|xx| xx["ts"]}}.flatten}.flatten
      stamps.each do |stamp|
        next if results.collect(&:first).include?(stamp) && results.select{|x| x[0] == stamp}.first[1] != 0
        puts stamp
        #open("https://web.archive.org/web/#{stamp}/https://www.reddit.com/r/The_Donald/").read
        $results = nil
        while $results.nil?
          begin
            $results = Nokogiri.parse(`curl 'https://web.archive.org/web/#{stamp}/https://www.reddit.com/r/The_Donald/' -H 'Pragma: no-cache' -H 'DNT: 1' -H 'Accept-Encoding: gzip, deflate, br' -H 'Accept-Language: en-US,en;q=0.9' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' -H 'Cache-Control: no-cache' -H 'Referer: https://web.archive.org/web/*/http://reddit.com/r/the_donald' -H 'Cookie: s_pers=%20s_nr%3D1519182822143-New%7C1521774822143%3B%20s_lastvisit%3D1519182822148%7C1613790822148%3B%20s_vnum%3D1521774822159%2526vn%253D1%7C1521774822159%3B%20s_invisit%3Dtrue%7C1519184622159%3B%20gvp_p5%3Dwp%2520-%2520article%2520-%2520AR2010102106645%2520-%2520Lillian%2520McEwen%2520breaks%2520her%252019-year%2520silence%2520about%2520Justice%2520Clarence%2520Thomas%7C1519184622174%3B%20gvp_pn%3Dwp%2520-%2520article%2520-%2520AR2010102106645%2520-%2520Lillian%2520McEwen%2520breaks%2520her%252019-year%2520silence%2520about%2520Justice%2520Clarence%2520Thomas%7C1519184622181%3B; _ga=GA1.2.1805523511.1519247057; _recent_srs=t5_2u7i2' -H 'Connection: keep-alive' --compressed`)
            $results = Nokogiri.parse(open("https://web.archive.org/web/#{stamp}/https://www.reddit.com/r/The_Donald/").read) if $results.children.empty?
            subscribers = $results.search(".subscribers .number").inner_html.gsub(",", "").to_i
            users_online = $results.search(".users-online .number").inner_html.gsub(",", "").to_i
            results << [stamp, subscribers, users_online]
          rescue OpenURI::HTTPError => e
            if e.to_s == "429 Too Many Requests"
              $results = []
              next
            elsif e.to_s == "403 Forbidden"
              $results = []
              next
            else
              retry
            end
          rescue Net::OpenTimeout => e
            retry
          end
        end
      end
    end
  end
  
  def backfill_accounts
    comment_counts = {}
    first_comment_times = {}
    last_comment_times = {}
    i = 0
    $client[:reddit_comments].find.projection("author" => 1, "created_utc" => 1).each do |comment|
      i += 1
      puts i if i % 10000 == 0
      comment_counts[comment["author"]] ||= 0
      comment_counts[comment["author"]] += 1
      first_comment_times[comment["author"]] ||= comment["created_utc"].to_i
      first_comment_times[comment["author"]] = comment["created_utc"].to_i if comment["created_utc"].to_i < first_comment_times[comment["author"]]
      last_comment_times[comment["author"]] ||= comment["created_utc"].to_i
      last_comment_times[comment["author"]] = comment["created_utc"].to_i if comment["created_utc"].to_i > last_comment_times[comment["author"]]
    end;false
    submission_counts = {}
    first_submission_times = {}
    last_submission_times = {}
    i = 0
    $client[:reddit_submissions].find.projection("author" => 1, "created_utc" => 1).each do |submission|
      i += 1
      puts i if i % 10000 == 0
      submission_counts[submission["author"]] ||= 0
      submission_counts[submission["author"]] += 1
      first_submission_times[submission["author"]] ||= submission["created_utc"].to_i
      first_submission_times[submission["author"]] = submission["created_utc"].to_i if submission["created_utc"].to_i < first_submission_times[submission["author"]]
      last_submission_times[submission["author"]] ||= submission["created_utc"].to_i
      last_submission_times[submission["author"]] = submission["created_utc"].to_i if submission["created_utc"].to_i > last_submission_times[submission["author"]]
    end;false
    $client[:reddit_authors].drop
    $client[:reddit_authors].indexes.create_one({ author: 1 }, unique: true)
    to_insert = []
    (comment_counts.keys|submission_counts.keys).each do |author|
    to_insert << {"author" => author, 
    "comment_count" => comment_counts[author].to_i,
    "last_comment_seen" => last_comment_times[author],
    "first_comment_seen" => first_comment_times[author],
    "submission_count" => submission_counts[author].to_i,
    "last_submission_seen" => last_submission_times[author],
    "first_submission_seen" => first_submission_times[author]}
    end;false
    to_insert.each_slice(1000) do |slice|
      print "."
      $client[:reddit_authors].insert_many(slice, ordered: false)
    end;false
  end
  
  def domain_counts
    domain_counts = {}
    $client[:reddit_submissions].find.projection(url: 1).each do |submission|
      host = URI.parse(submission["url"]).host rescue nil
      domain_counts[host] ||= 0
      domain_counts[host] += 1
    end;false
    scored_domains = []
    domain_counts.each do |domain, count|
      next if domain.nil? || $client[:domains].find(domain: domain).first
      scored_domains << AlexaRank.new.get_score(domain).merge(hit_count: count) rescue nil
      if scored_domains.length > 100
        $client[:domains].insert_many(scored_domains.compact, ordered: false)
        scored_domains = []
      end
    end    
  end
end
