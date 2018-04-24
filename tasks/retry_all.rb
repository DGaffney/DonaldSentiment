class RetryAll
  include Sidekiq::Worker
  def perform
    Sidekiq::RetrySet.new.collect(&:retry)
  end
end