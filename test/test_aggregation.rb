$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__),"..")
require 'rubygems'
require 'plantwatchdog/model'
require 'plantwatchdog/aggregation'
require 'test/unit'
require 'test/test_base'

module PlantWatchdog
  class ModelTest < Test::Unit::TestCase
    include TestUtil
    def test_device_aggregation
      # make sure that the aggregation Methods are called correctly
      # device
      year = 2010
      day = 50
      plant = Model::Plant.new

      inv_aggrules =  { "agg1" =>  [:aggZeroParam],  "agg2" =>  [:aggOneParam, :time], "agg3" => [:aggTwoParams, :time, :pac] }
      inv_meta = [["time", "integer"], ["pac", "integer"]]
      inverter1 = Model::Device.new
      inverter1.aggrules = inv_aggrules
      inverter1.plant = plant
      inverter1.meta = inv_meta
      inverter1.save!

      invMeasurement = Model::MeasurementChunk.new()
      invMeasurement.time_year = year
      invMeasurement.time_day_of_year = day
      invMeasurement.meta = inv_meta # TODO set automatically
      invMeasurement.data = <<EOF
12,33
16,0
EOF
      invMeasurement.device = inverter1
      invMeasurement.save!

      calledZeroParam = nil
      calledOneParam = nil
      calledTwoParams = nil

      Aggregation::Methods.send(:define_method, :aggZeroParam, Proc.new { calledZeroParam = true })
      Aggregation::Methods.send(:define_method, :aggOneParam, Proc.new { |p1| calledOneParam = p1 })
      Aggregation::Methods.send(:define_method, :aggTwoParams, Proc.new { |p1,p2| calledTwoParams = [p1,p2] })

      aggDevice = Aggregation::Device.create(inverter1, year, day)
      aggDevice.aggregate

      assert_equal(true, calledZeroParam)
      assert_equal([12,16], calledOneParam)
      assert_equal([[12,16], [33,0]], calledTwoParams)

      Aggregation::Methods.send(:define_method, :nested, Proc.new { |t| t.first + t.last })
      inverter1.aggrules = { "nested" => [:mult, 0.5, [:nested, :time]] }
      device_aggregate = aggDevice.aggregate()
      assert_equal(14, device_aggregate["nested"])

      plant.aggrules = { "picked" => [ :pick, 0, :nested] }
      plant.save!

      aggPlant = Aggregation::Plant.new(plant, [ device_aggregate ])
      assert_equal(14, aggPlant.aggregate()["picked"])
    end

    def test_aggregation
      year = 2010
      day = 50
      plant = Model::Plant.new
      plant.aggrules = { "eday" => [:sum, "eday"] }
      plant.save

      sunmeter = Model::Device.new
      sunmeter.aggrules = { :avg_temperature => [:avg, :temperature], "irradiance" => [:integrate, :time, :irradiance] }
      sunmeter.plant = plant
      sunmeter.meta = [["time", "integer"], ["temperature", "integer"], ["irradiance", "integer"]]
      sunmeter.save!

      envMeasurement = Model::MeasurementChunk.new()
      envMeasurement.time_year = year
      envMeasurement.time_day_of_year = day
      envMeasurement.data = <<EOF
12,32,500
15,30,480
EOF
      envMeasurement.device = sunmeter
      # TODO meta should be taken from sunmeter automatically
      envMeasurement.meta = sunmeter.meta
      envMeasurement.save!

      # create two inverters with the same metadata
      inv_aggrules =  { "eday" =>  [:growth, :etotal], "pac" => [:integrate, :time, :pac], "expected" => [ :expected] }
      inv_meta = [["time", "integer"], ["pac", "integer"], ["etotal", "float"]]
      inverter1 = Model::Device.new
      inverter1.aggrules = inv_aggrules
      inverter1.plant = plant
      inverter1.meta = inv_meta
      inverter1.save!

      invMeasurement = Model::MeasurementChunk.new()
      invMeasurement.time_year = year
      invMeasurement.time_day_of_year = day
      invMeasurement.meta = inv_meta # TODO set automatically
      invMeasurement.data = <<EOF
12,33,60.1
16,0,60.5
EOF
      invMeasurement.device = inverter1
      invMeasurement.save!

      inverter2 = Model::Device.new
      inverter2.aggrules = inv_aggrules
      inverter2.plant = plant
      inverter2.meta = inv_meta
      inverter2.save!

      invMeasurement = Model::MeasurementChunk.new()
      invMeasurement.time_year = year
      invMeasurement.time_day_of_year = day
      invMeasurement.meta = inv_meta # TODO set automatically
      invMeasurement.data = <<EOF
12,43,90.1
14,50,100.0
18,35,105.0
EOF
      invMeasurement.device = inverter2
      invMeasurement.save!

      runner = Aggregation::Runner.new
      agg_sunmeter, agg_inv1, agg_inv2, agg_plant = runner.aggregate(Model::Plant.find(:first), year, day)
      assert_equal(31, agg_sunmeter.data["avg_temperature"])
      eday_inv1 = 60.5 - 60.1 ; eday_inv2 = 105.0 - 90.1;
      pac_inv1 = 4 * 33 / 2.0
      assert_equal(eday_inv1, agg_inv1.data["eday"])
      assert_equal(pac_inv1, agg_inv1.data["pac"])
      assert_equal(eday_inv2, agg_inv2.data["eday"])
      assert_equal(eday_inv1 + eday_inv2, agg_plant.data["eday"])

      # check that daily aggregate entry was created in db
      saved_plant_agg = Model::MeasurementAggregate.find(:first, :conditions => ["plant_id=?", plant.id])
      assert_equal(year, saved_plant_agg.time_year)
      assert_equal(day, saved_plant_agg.time_day_of_year)
      assert(saved_plant_agg.data.keys.include?("eday"))

    end

    def test_find_missing_aggregates
      inverter = create_inverter

      chunk = Model::MeasurementChunk.new()
      chunk.time_year = 2222
      chunk.time_day_of_year = 52
      chunk.device = inverter
      chunk.save!

      runner = Aggregation::Runner.new
      assert_equal([[chunk.time_year, chunk.time_day_of_year, inverter.plant.id]], runner.find_missing_aggregates)
      runner.run
      assert_equal([], runner.find_missing_aggregates)
    end
  end
end