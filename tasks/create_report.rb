class CreateReport
  include Sidekiq::Worker
  def perform(cursor=Time.at(TimeDistances.time_ten_minute(Time.now)).utc.to_i)
    report = Report.snapshot(cursor)
    $client[:stats].insert_one(time: cursor, content: report)
  end
end

#Sidekiq::Cron::Job.create(name: 'Report Creator', cron: '*/10 * * * *', class: 'CreateReport') # execute at every 5 minutes, ex: 12:05, 12:10, 12:15...etc
#Sidekiq::Cron::Job.create(name: 'Report Creator', cron: '0 1 * * *', class: 'LongTermReport') # execute at every 5 minutes, ex: 12:05, 12:10, 12:15...etc
