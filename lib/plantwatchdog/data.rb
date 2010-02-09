# Copyright (C) 2010 Markus Barchfeld, Vassilis Rizopoulos
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>.
$:.unshift File.join(File.dirname(__FILE__),"..")
require 'plantwatchdog/model'

module PlantWatchdog
  module Datadetection
    def years_with_data(user)
      start_year = user.start_year
      end_year = user.end_year
      return [] unless start_year and end_year
      return (start_year .. end_year).to_a
    end

    def days_with_data(user, year)
      device_ids = user.plant.devices.collect { |d| d.id.to_s }
      rows = ActiveRecord::Base.connection.select_all("select distinct time_day_of_year from measurement_chunks where device_id in (#{device_ids.join(",")}) and time_year=#{year} order by time_day_of_year")
      return rows.collect {|r| r['time_day_of_year'].to_i}
    end

    # extract timeseries from the data chunks
    # helpers for the presentation layer

    def utc_offset(user, secs_since_epoch)
      # mind that the offset also depends on daylight_saving_time
      # use libc to transform timezones, does not work on windows,
      # there is a pure ruby implementation, too
      ENV["TZ"] = user.timezone # eg "Europe/Berlin"
      offset = Time.at(secs_since_epoch).utc_offset
      ENV["TZ"] = "UTC"
      return offset
    end

    def time_series(inverter, year, day_of_year)
      chunk = Model::MeasurementChunk.find(:first, :conditions => ["device_id=? and time_year=? and time_day_of_year=?", inverter.id, year, day_of_year])
      result= {}
      return result unless chunk
      # ENV["TZ"] must be set, does not work on windows
      utc_offset = chunk.measurements.empty? ? 0 : Time.at(chunk.measurements.first.time).utc_offset
      keys = chunk.meta.collect {|m| m.first} - ["time"]
      keys.each {
        |key|
        result[key] = chunk.measurements.collect {
          |m|
          [(m.time + utc_offset) * 1000, m[key]]
        }
      }
      return result
    end

    def plant_aggregates(plant, days)
      result = {}
      plant.aggrules.keys.each { |k| result[k] = [] }
      daymillis = 3600*24*1000
      # TODO: check for changed aggrules
      days.each {
        | a |
        year = a.first
        yday = a.second
        year_start_millis = Time.utc(year, "jan", 1, 12, 0, 0).tv_sec * 1000
        time_millis = year_start_millis + (yday-1)*daymillis
        chunk = Model::MeasurementAggregate.find(:first, :conditions => ["plant_id=? and time_year=? and time_day_of_year=?", plant.id, year, yday])
        plant.aggrules.keys.each {
          |key|
          value = 0
          if (chunk) then
            v = chunk.data[key]
            value = v if v
          end
          result[key] << [time_millis, value]
        }
      }
      return result
    end

  end

  module Monthhelper
    def days_of_month(year, month)
      t = Time.utc(year, month, 1, 12, 0, 0)
      result = [t]
      while (true)
        t += 3600*24
        break if t.month != month
        result << t
      end
      return result
    end
  end

  class DayOfYearConverter
    def initialize(year, days_of_year)
      @year = year
      start = Time.utc(year, 1, 1)
      @days_of_year = days_of_year.collect { |d| secs_of_year = (d - 1) * 3600*24 ; start + secs_of_year }
      logger.debug "DayOfYearConverter: Added #{@days_of_year.size} days for year #{@year}"
    end

    def months
      logger.debug "DayOfYearConverter: Searching for months in #{@year}, #{self}"
      months = @days_of_year.collect{|d| d.month }
      months.uniq!
      months
    end

    def days(month)
      logger.debug "DayOfYearConverter: Searching days for #{month} in #{@year}, #{self}"
      @days_of_year.select{|d| d.month == month}.collect{|d| d.day}
    end

    def logger
      return ActiveRecord::Base.logger
    end
  end
end