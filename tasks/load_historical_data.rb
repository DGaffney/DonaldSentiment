class LoadHistoricalData
  include Sidekiq::Worker
  sidekiq_options queue: :load_history
  def perform(file, path, filetype)
    rows = []
    File.open(path+file).each_line do |row|
      rows << (JSON.parse(row) rescue nil)
      if rows.length > 100
        $client["reddit_#{filetype}".to_sym].insert_many(rows.compact, ordered: false)
        rows = []
      end
    end
    $client["reddit_#{filetype}".to_sym].insert_many(rows.compact, ordered: false)
  end

  def self.kickoff(path="/media/dgaff/Main2/DonaldSentiment/Donald/")
    `ls #{path}`.split("\n").shuffle.each do |file|
      if file.include?("RS")
        LoadHistoricalData.perform_async(file, path, "submissions")
      elsif file.include?("RC")
        LoadHistoricalData.perform_async(file, path, "comments")
      end
    end
  end
end