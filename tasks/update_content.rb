class UpdateContent
  include Sidekiq::Worker
  sidekiq_options queue: :updater
  def perform(data_type)
    if data_type != "subreddit"
      run(data_type)
    else
      run_subscriber_count_update
    end
  end

  def request_ids(ids)
    JSON.parse(`curl 'https://api.reddit.com/api/info.json?id=#{ids.join(",")}' -H 'pragma: no-cache' -H 'dnt: 1' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' -H 'cache-control: no-cache' -H 'authority: api.reddit.com' -H 'cookie: eu_cookie_v2=3; edgebucket=rf7b7QwZG2nqorMB4t; reddaid=27LPZXE6XSJZFDAB; _ga=GA1.2.500892711.1415128777; datatest_recent_srs=t5_2rh4f%2Ct5_31vg4%2Ct5_3288l%2Ct5_2fwo%2Ct5_3gwfd%2Ct5_2rjq4%2Ct5_2qh0u%2Ct5_2rbsj%2Ct5_2xhxs%2Ct5_37z6f; _recent_srs=t5_2st7f%2Ct5_2rjwd%2Ct5_2ti4h%2Ct5_2qh33%2Ct5_2qh1e%2Ct5_2qhlh%2Ct5_2qh87%2Ct5_32njv%2Ct5_2to41%2Ct5_2skqi; reddit_session=7986755%2C2018-01-28T21%3A24%3A20%2C75b717471817ed83def71af393e3c5caa003df25; loid=00000000000004r6mb.2.1295691676925.Z0FBQUFBQmFickFGMmN0aE1Od0V6OGkyNlNVcF94UWxySjFOQ2E5TGJ3WmEwOHVNNk0xSWQ0VzRIV2FqdERUWnU2N3QyMDV4RTliZ2tUMEU5OUctRjhubDFsUEljRzg3c1p6S1FQalRtQzlxYkI0WWIxYkdJYmlrNzRFNko3Q2psOTh6RHNLUGxCSmI; rseor2=; rseor3=; rabt=; pc=zk; token=eyJhY2Nlc3NUb2tlbiI6ImN5THltc1lqQW80VlVndTZfNVF1TC1GSEZhZyIsInRva2VuVHlwZSI6ImJlYXJlciIsImV4cGlyZXMiOiIyMDE4LTA0LTA2VDE3OjE0OjEyLjYyNloiLCJyZWZyZXNoVG9rZW4iOiI3OTg2NzU1LVUtcXpXd2oxaTZZVEVyN0ZnNEJ3Ny1tQ1RQUSIsInNjb3BlIjoiYWNjb3VudCBjcmVkZGl0cyBlZGl0IGZsYWlyIGhpc3RvcnkgaWRlbnRpdHkgbGl2ZW1hbmFnZSBtb2Rjb25maWcgbW9kY29udHJpYnV0b3JzIG1vZGZsYWlyIG1vZGxvZyBtb2RtYWlsIG1vZG90aGVycyBtb2Rwb3N0cyBtb2RzZWxmIG1vZHdpa2kgbXlzdWJyZWRkaXRzIHByaXZhdGVtZXNzYWdlcyByZWFkIHJlcG9ydCBzYXZlIHN0cnVjdHVyZWRzdHlsZXMgc3VibWl0IHN1YnNjcmliZSB2b3RlIHdpa2llZGl0IHdpa2lyZWFkIn0=.2; _gid=GA1.2.872295448.1523151276; __utmc=55650728; dgaff_recent_srs=t5_38unr%2Ct5_2qizd%2Ct5_2cneq%2Ct5_2qh1s%2Ct5_2x9xz%2Ct5_3687c%2Ct5_2s7po%2Ct5_3cqa1%2Ct5_2ygc4%2Ct5_2wlj3; dgaff_recentclicks2=t3_8b6if6%2Ct3_8b2qdw%2Ct3_8b1i3m%2Ct3_8aycj5%2Ct3_88voqt; __utma=55650728.500892711.1415128777.1523364837.1523365100.1213; __utmz=55650728.1523365100.1213.566.utmcsr=reddit|utmccn=(not%20set)|utmcmd=hot|utmcct=title; session_tracker=Ow7JtwbefqjjGyVNxw.0.1523373914661.Z0FBQUFBQmF6TmRhYnk5SF9yVTdTc3g3ZmxGRlZyT1JENkl4Q2phN3pOT29VUkFtWU9WQ0d2M01LRnhUSEcya0YxRmMzSWlMZnE2YTY2Ym91bWhqc3dtYkgxREhTU0ZYSjk5TWh3c3ZiTWdlMUVVdFY3ZVVlNExkejhGeV9aTzZVMEFQc1RhVFFoT3E' --compressed`) rescue nil
  end

  def request_subreddit
    Nokogiri.parse(`curl 'https://www.reddit.com/r/The_Donald/' -H 'pragma: no-cache' -H 'dnt: 1' -H 'accept-encoding: gzip, deflate, br' -H 'accept-language: en-US,en;q=0.9' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' -H 'cache-control: no-cache' -H 'authority: www.reddit.com' -H 'cookie: eu_cookie_v2=3; _recent_srs=t5_2rjwd%2Ct5_2ti4h%2Ct5_2qh33%2Ct5_2qh1e%2Ct5_2qhlh%2Ct5_2qh87%2Ct5_32njv%2Ct5_2to41%2Ct5_2skqi%2Ct5_2tycb; edgebucket=rf7b7QwZG2nqorMB4t; reddaid=27LPZXE6XSJZFDAB; _ga=GA1.2.500892711.1415128777; datatest_recent_srs=t5_2rh4f%2Ct5_31vg4%2Ct5_3288l%2Ct5_2fwo%2Ct5_3gwfd%2Ct5_2rjq4%2Ct5_2qh0u%2Ct5_2rbsj%2Ct5_2xhxs%2Ct5_37z6f; _recent_srs=t5_2st7f%2Ct5_2rjwd%2Ct5_2ti4h%2Ct5_2qh33%2Ct5_2qh1e%2Ct5_2qhlh%2Ct5_2qh87%2Ct5_32njv%2Ct5_2to41%2Ct5_2skqi; reddit_session=7986755%2C2018-01-28T21%3A24%3A20%2C75b717471817ed83def71af393e3c5caa003df25; loid=00000000000004r6mb.2.1295691676925.Z0FBQUFBQmFickFGMmN0aE1Od0V6OGkyNlNVcF94UWxySjFOQ2E5TGJ3WmEwOHVNNk0xSWQ0VzRIV2FqdERUWnU2N3QyMDV4RTliZ2tUMEU5OUctRjhubDFsUEljRzg3c1p6S1FQalRtQzlxYkI0WWIxYkdJYmlrNzRFNko3Q2psOTh6RHNLUGxCSmI; rseor2=; rseor3=; rabt=; pc=zk; token=eyJhY2Nlc3NUb2tlbiI6ImN5THltc1lqQW80VlVndTZfNVF1TC1GSEZhZyIsInRva2VuVHlwZSI6ImJlYXJlciIsImV4cGlyZXMiOiIyMDE4LTA0LTA2VDE3OjE0OjEyLjYyNloiLCJyZWZyZXNoVG9rZW4iOiI3OTg2NzU1LVUtcXpXd2oxaTZZVEVyN0ZnNEJ3Ny1tQ1RQUSIsInNjb3BlIjoiYWNjb3VudCBjcmVkZGl0cyBlZGl0IGZsYWlyIGhpc3RvcnkgaWRlbnRpdHkgbGl2ZW1hbmFnZSBtb2Rjb25maWcgbW9kY29udHJpYnV0b3JzIG1vZGZsYWlyIG1vZGxvZyBtb2RtYWlsIG1vZG90aGVycyBtb2Rwb3N0cyBtb2RzZWxmIG1vZHdpa2kgbXlzdWJyZWRkaXRzIHByaXZhdGVtZXNzYWdlcyByZWFkIHJlcG9ydCBzYXZlIHN0cnVjdHVyZWRzdHlsZXMgc3VibWl0IHN1YnNjcmliZSB2b3RlIHdpa2llZGl0IHdpa2lyZWFkIn0=.2; _gid=GA1.2.872295448.1523151276; __utmc=55650728; dgaff_recentclicks2=t3_8ba05e%2Ct3_8b6if6%2Ct3_8b2qdw%2Ct3_8b1i3m%2Ct3_8aycj5; __utmz=55650728.1523385525.1218.569.utmcsr=reddit|utmccn=(not%20set)|utmcmd=front|utmcct=permalink; wpsn=false; dgaff_recent_srs=t5_38unr%2Ct5_2qh23%2Ct5_2cneq%2Ct5_2qizd%2Ct5_2qh1s%2Ct5_2x9xz%2Ct5_3687c%2Ct5_2s7po%2Ct5_3cqa1%2Ct5_2ygc4; __utma=55650728.500892711.1415128777.1523385525.1523389403.1219; __utmb=55650728.0.10.1523389403; session_tracker=c5GPYrCYoDJkJ3boUE.0.1523389626420.Z0FBQUFBQmF6UlM2cVQtVkFtbm9VektKLXFlM0lOaG5XLVFFTG9GZzJXSFFkTDg3LVpnTzZYeEtkQnl1TkZuYTl4eTIyUHZwWUk5T0Y1cFhUNUtZMi0zQjlMVjdjaTZySmQtTDlUUXAyMUlPU2diVktnTXlmbTR6aURvRm5nb0wwanluZy1NR3gyVEk' --compressed`) rescue nil
  end

  def clean_results(ids, response)
    Hash[response["data"]["children"].collect{|r| [r["kind"]+"_"+r["data"]["id"], {admin_deleted: (r["data"]["body"] == "[removed]"), user_deleted: (r["data"]["body"] == "[deleted]"), ups: r["data"]["ups"], gilded: r["data"]["gilded"], edited: r["data"]["edited"]}]}]
  end
  
  def found_docs(ids)
    t = Time.now.utc.to_i
    begin    
      return clean_results(ids, request_ids(ids))
      sleep(1)
    rescue
      retry
    end
  end

  def update(data_type="comments")
    collection = data_type == "comments" ? :reddit_comments : :reddit_submissions
    t_term = data_type == "comments" ? "t1_" : "t3_"
    t = Time.parse(Time.now.strftime("%Y-%m-%d %H:%M:00")).utc.to_i
    #1.upto(144).collect{|x| [t-x*600-30, t-x*600+30]}
    ids = 1.upto(144).collect{|x| {"created_utc" => {"$gte" => t-x*600-30, "$lte" => t-x*600+30}}}.collect{|q| $client[collection].find(q).collect{|x| t_term+x["id"]}};false
    id_age_check = {}
    ids.each_with_index do |id_set, i|
      id_set.each do |id|
        id_age_check[id] = (i+1) * 600
      end
    end
    all_documents = {}
    ids.flatten.shuffle.each_slice(100) do |id_set|
      all_documents.merge!(Hash[found_docs(id_set).collect{|id,stats| [id, stats.merge(delay: id_age_check[id])]}])
    end
    all_documents.each do |id, updates|
      $client[collection].update_one({id: id.split("_").last}, {"$push" => {updated_info: updates}}, {upsert: true})
    end;false
  end
  
  def run(data_type="comments")
    t = Time.parse(Time.now.strftime("%Y-%m-%d %H:%M:00")).utc.to_i
    while true
      sleep(3)
      tt = Time.parse(Time.now.strftime("%Y-%m-%d %H:%M:00")).utc.to_i
      if tt != t
        t = Time.parse(Time.now.strftime("%Y-%m-%d %H:%M:00")).utc.to_i
        UpdateContent.new.update(data_type) 
      end
    end
  end
  
  def run_subscriber_count_update
    t = Time.parse(Time.now.strftime("%Y-%m-%d %H:%M:00")).utc.to_i
    while true
      sleep(1)
      tt = Time.parse(Time.now.strftime("%Y-%m-%d %H:%M:00")).utc.to_i
      if tt-t > 600
        response = request_subreddit
        $client[:subreddit_counts].insert_one({time: Time.now.utc.to_i, subscribers: response.search(".subscribers .number").children.first.to_s.gsub(",", "").to_i, active_users: response.search(".users-online .number").children.first.to_s.gsub(",", "").to_i})
        t = Time.parse(Time.now.strftime("%Y-%m-%d %H:%M:00")).utc.to_i
      end
    end
  end
  
  def upload_historical_subscriber_counts
    CSV.read("historical_subscriber_counts.csv").reject{|x| x[1].to_i == 0}.collect{|x| {time: Time.parse(x[0][0..3]+"-"+x[0][4..5]+"-"+x[0][6..7]+" "+x[0][8..9]+":"+x[0][10..11]+":"+x[0][12..13]+" +0000").to_i, subscribers: x[1].to_i, active_users: x[2].to_i}}.each_slice(1000) do |sub_set|
      $client[:subreddit_counts].insert_many(sub_set)
    end
  end
  
  def self.kickoff
    UpdateContent.perform_async("comments")
    UpdateContent.perform_async("submissions")
    UpdateContent.perform_async("subreddit")
  end
end

