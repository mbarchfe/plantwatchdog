$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__),"..")
require 'rubygems'
require 'plantwatchdog/data'
require 'test/unit'
require 'test/test_base'

module PlantWatchdog
  class DataTest < Test::Unit::TestCase
    include TestUtil
    include Datadetection
    def test_raw_data_years
      inverter1 = create_inverter

      year = 2006
      date = Time.utc(year, "jan", 2, 5, 0, 0)

      # add a measurement for inverter1
      Model::MeasurementChunk.save_measurements(inverter1, [create_measurement(date.tv_sec, 25.0, 10000)])

      assert_equal [year], years_with_data(user)
      assert_equal [2], days_with_data(user, 2006)

      # add inverter2 and a measurement for another day in the same year
      date = Time.utc(year, "feb", 1, 5, 0, 0)
      inverter2 = create_inverter
      Model::MeasurementChunk.save_measurements(inverter1, [create_measurement(date.tv_sec, 25.0, 10000)])
      Model::MeasurementChunk.save_measurements(inverter2, [create_measurement(date.tv_sec, 25.0, 10000)])
      assert_equal [year], years_with_data(user)
      assert_equal [2,32], days_with_data(user, 2006)

      # add a measurement for the next year
      date = Time.utc(year+1, "feb", 2, 5, 0, 0)
      Model::MeasurementChunk.save_measurements(inverter2, [create_measurement(date.tv_sec, 25.0, 10000)])
      assert_equal [year, year+1], years_with_data(user)
      assert_equal [33], days_with_data(user, 2007)
    end

    def test_day_of_year_converter
      # 2000 is a switch year
      dayc = DayOfYearConverter.new(2000, [1,60])
      assert_equal [1,2], dayc.months
      assert_equal [1], dayc.days(1)
      assert_equal [29], dayc.days(2)
      assert_equal [], dayc.days(3)
      dayc = DayOfYearConverter.new(2001, [1,60])
      assert_equal [1,3], dayc.months
      assert_equal [1], dayc.days(1)
      assert_equal [], dayc.days(2)
      assert_equal [1], dayc.days(3)
    end

    def test_series
      inverter = create_inverter
      date = Time.utc(2001, "jan", 2, 12, 0, 0)

      # add a measurement for inverter1
      Model::MeasurementChunk.save_measurements(inverter, [create_measurement(date.tv_sec, 25.1, 101)])
      ENV["TZ"] = "Europe/Berlin" # set timezone
      ts = time_series(inverter, 2001, 2)
      ts_pac = ts["pac"]
      utc_offset = 3600 # Berlin is GMT+1 in January
      # the time in timeseries is milliseconds and faked local time:
      # the secs_since_epoch is adjusted to fake local time, see flot documentation
      assert_equal([(date.tv_sec + utc_offset)*1000, 25.1], ts_pac[0])

      ts_etotal=ts["etotal"]
      assert_equal([(date.tv_sec + utc_offset)*1000, 101], ts_etotal[0])

    end

    def test_plant_agg
      create_inverter
      plant = user.plant
      plant.aggrules = { "eday" => [:sum, "eday"] }
      plant.save
      ma1 = Model::MeasurementAggregate.new
      ma1.plant = plant
      ma1.data = { "eday" => 1.2 }
      ma1.time_year = 2010
      ma1.time_day_of_year = 20
      ma1.save!

      # 2010-21 missing

      ma2 = Model::MeasurementAggregate.new
      ma2.plant = plant
      ma2.data = { "eday" => 1.4 , "another" => 1 }
      ma2.time_year = 2010
      ma2.time_day_of_year = 22
      ma2.save!

      ma3 = Model::MeasurementAggregate.new
      ma3.plant = plant
      ma3.data = { "another" => 1 }
      ma3.time_year = 2010
      ma3.time_day_of_year = 23
      ma3.save!

      aggs = plant_aggregates(plant, [[2010,19],[2010,20],[2010,21],[2010,22],[2010,23]])
      ENV["TZ"] = "Europe/Berlin" # set timezone
      millis = Time.utc(2010, "jan", 19, 12, 0, 0).tv_sec*1000
      day_millis = 3600*24*1000
      # TODO NaN instead of 0
      assert_equal( [[millis, 0], [millis+day_millis, 1.2], [millis+day_millis*2, 0], [millis+day_millis*3, 1.4], [millis+day_millis*4, 0]], aggs["eday"])
    end

    include Monthhelper

    def test_monthhelper
      assert_equal(31, days_of_month(2000, 1).size)
      assert_equal(29, days_of_month(2000, 2).size)
      assert_equal(30, days_of_month(2000, 4).size)
      assert_equal(28, days_of_month(2001, 2).size)
    end

  end
end