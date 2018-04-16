class TimeDistances
  def self.time_minute(time)
    Time.parse(time.utc.strftime("%Y-%m-%d %H:%M:00 +0000")).to_i
  end

  def self.time_ten_minute_previous(time)
    time = time-500 #little less than 10 minutes to avoid previous previous
    strftmin = time.utc.strftime("%M")[0]
    Time.parse(time.utc.strftime("%Y-%m-%d %H:#{strftmin}0:00 +0000")).to_i
  end

  def self.time_ten_minute(time)
    strftmin = time.utc.strftime("%M")[0]
    Time.parse(time.utc.strftime("%Y-%m-%d %H:#{strftmin}0:00 +0000")).to_i
  end

  def self.time_hour(time)
    Time.parse(time.utc.strftime("%Y-%m-%d %H:00:00 +0000")).to_i
  end

  def self.hourly_day(time)
    1.upto(24).collect{|x| [self.time_hour(time)-x*60*60, self.time_hour(time)-(x+1)*60*60]}
  end

  def self.hour_week(time)
    1.upto(7).collect{|x| [self.time_hour(time)-x*60*60, self.time_hour(time)-(x+1)*60*60]}
  end

  def self.hour_day_month(time)
    1.upto(4).collect{|x| [self.time_hour(time)-(x)*7*24*60*60, self.time_hour(time)-(x)*7*24*60*60-60*60]}
  end
  
  def self.time_bands(time)
    {"10_minutes_past_day" => self.ten_minutes_past_day(time), "24_hours" => self.hourly_day(time), "hours_in_week" => self.hour_week(time), "hour_days_past_month" => self.hour_day_month(time)}
  end

  def self.past_24_hours(time)
    [[self.time_minute(time), self.time_minute(time)-60*60*24]]
  end

  def self.ten_minute_time_range(time)
    [self.time_ten_minute(time), self.time_ten_minute(time)-600]
  end

  def self.time_queries(time)
    {"10_minutes_past_day" => self.past_24_hours(time), "24_hours" => self.past_24_hours(time), "hours_in_week" => self.hour_week(time), "hour_days_past_month" => self.hour_day_month(time)}
  end
  
  def self.ten_minutes_past_day(time)
    1.upto(144).collect{|x| [self.time_minute(time)-x*600, self.time_minute(time)-(x+1)*600]}
  end
end
