class CreateReport
  include Sidekiq::Worker
  def perform(cursor=Time.now.utc.to_i)
    cursor = Time.at(cursor)
    report = Report.snapshot(cursor)
    $client[:stats].insert_one(time: cursor, content: report)
  end
end

#Sidekiq::Cron::Job.create(name: 'Report Creator', cron: '*/10 * * * *', class: 'CreateReport') # execute at every 5 minutes, ex: 12:05, 12:10, 12:15...etc
