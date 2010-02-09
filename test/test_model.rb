$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__),"..")
require 'rubygems'
require 'plantwatchdog/model'
require 'test/unit'
require 'test/test_base'

module PlantWatchdog
  class ModelTest < Test::Unit::TestCase
    include TestUtil
    def test_measurement_parse_csv
      inverter = create_inverter

      year = 2006
      date = Time.utc(year, "jan", 2, 8, 0, 0)

      assert_equal([], Model::Measurement.parse_csv(inverter.metadata, nil))
      assert_equal([], Model::Measurement.parse_csv(inverter.metadata, ""))

      csv = "#{date.tv_sec},25.00,10000"
      actual = Model::Measurement.parse_csv inverter.metadata, csv
      expected =  [ create_measurement(date.tv_sec, 25.0, 10000) ]
      assert_equal(expected, actual)

      # to_csv: a measurement instance must preserver the original line
      assert_equal(csv, actual.first.line)

      # expected.first has not been created from a csv line, the line
      # must be created according to the metadata, therefore 25.0 will
      # be serialized as "25.0"
      assert_equal("#{date.tv_sec},25.0,10000", expected.first.line)
    end

    def test_save_measurement
      inverter = create_inverter
      ENV["TZ"] = "Europe/Berlin"
      year = 2006
      date = Time.utc(year, "jan", 1, 23, 0, 0) # this is January 2, 00:00:00 in Berlin

      m = create_measurement(date.tv_sec, 25.0, 10000)
      Model::MeasurementChunk.save_measurements(inverter, [m])

      # re-read the chunk and therefore go through the complete de-serialization
      c = Model::MeasurementChunk.find(:first)
      assert_equal(year, c.time_year)
      assert_equal(2, c.time_day_of_year)
      assert_equal(m, c.measurements.first)

      # create a new chunk for another inverter on the same day
      inverter2 = create_inverter
      Model::MeasurementChunk.save_measurements(inverter2, [m])
      c = Model::MeasurementChunk.find(:first, :conditions => [ "device_id=?", inverter2.id ])
      assert_equal(year, c.time_year)
      assert_equal(2, c.time_day_of_year)

    end

    def test_measurement_partition
      create_inverter()
      year = 2006
      date1 = Time.utc(year, "jan", 2, 8, 0, 0)
      date2 = Time.utc(year, "jan", 3, 8, 0, 0)

      measurements = []
      dict = Model::Measurement.partition_by_day measurements
      assert(dict.empty?)

      # one measurement, one day
      measurements << create_measurement(date1.tv_sec, 25.0, 10000)
      dict = Model::Measurement.partition_by_day measurements
      assert_equal(measurements, dict[[year,2]])

      # two measurements, one day
      measurements << create_measurement(date1.tv_sec + 1000, 25.0, 10000)
      dict = Model::Measurement.partition_by_day measurements
      assert_equal(measurements, dict[[year,2]])

      # three measurements, two days
      measurements << create_measurement(date2.tv_sec, 25.0, 10000)
      dict = Model::Measurement.partition_by_day measurements
      assert_equal(measurements[0,2], dict[[year,2]])
      assert_equal([measurements.last], dict[[year,3]])
    end

    def test_metadata_and_aggrules_conversion
      device = Model::Device.new
      # set metadata and aggrules via conveniance setters ...
      aggrules =  { "k" => [ "m", "p1"] } # TODO: Hash keys should be symbols, but default encoding/decoding to json only uses strings
      device.aggrules = aggrules
      device.meta = ["col1", "col2"]
      device.save!

      act_device = Model::Device.find(:first)
      # and check that the dict and array was transformed to JSON
      # access active record attributes directly since getter is overwritten
      assert_equal( '["col1","col2"]' , device.metadata["description"])
      assert_equal( '{"k":["m","p1"]}', device.aggregationrule["description"])

      # now check that the JSON from the descriptions has been transformed to ruby array and dict
      assert_equal( act_device.meta, device.meta)
      assert_equal( aggrules, act_device.aggrules)

      # check that updating meta and saving again creates a new
      # metadata row and the old one is preserved
      existing_metadata_id = device.metadata.id
      device.meta = ["col1", "col2", "col3"]
      device.save!
      assert(existing_metadata_id < device.metadata.id)
      act_device = Model::Device.find(:first)
      assert_equal( '["col1","col2","col3"]' , device.metadata["description"])
      old_metadata = Model::Metadata.find(:first, :conditions =>  ["id=?", existing_metadata_id])

      assert_equal('["col1","col2"]' , old_metadata["description"])

      # assigning the same metadata again must not create a new metadata instance
      current_metadata_id = device.metadata.id
      device.meta = ["col1", "col2", "col3"]
      device.save!
      assert( device.metadata.id == current_metadata_id)

    end

    def test_metadata
      # every metadata instance dynamically creates one subclass of BaseWithoutTable
      meta = Model::Metadata.new
      meta.description = '["default",["time","integer"],["value","float"]]'
      assert_equal(["default",["time","integer"],["value","float"]],  meta.description)
      cols = meta.dataclass.columns
      assert_equal("default", cols.first.name)
      assert_equal(nil, cols.first.type)
      assert_equal("time", cols[1].name)
      assert_equal(:integer, cols[1].type)
      assert_equal("value", cols.last.name)
      assert_equal(:float, cols.last.type)

      # ensure there is exactly one class created for every metadata row
      meta.save!
      loadedMeta = Model::Metadata.find(:first)
      assert_same(meta.dataclass, loadedMeta.dataclass)
    end
  end
end