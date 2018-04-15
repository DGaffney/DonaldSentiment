class CreateReport
  include Sidekiq::Worker
  def perform(cursor)
    report = Report.snapshot(cursor)
    $client[:stats].insert_one(time: cursor, content: report)
  end
end