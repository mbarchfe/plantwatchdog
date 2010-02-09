$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__),"..")
require 'rubygems'
require 'plantwatchdog/model'
require 'test/unit'
require 'test/test_base'

module PlantWatchdog
  class SyncTest < Test::Unit::TestCase
    include TestUtil
    def test_sync_inverter
      # sync inverter
      inverter = create_inverter()
      inverter.save
      year = 2005
      day = 5
      syncTime = Time.utc(year, "jan", day, 15, 0, 0)

      syncManager = Model::SyncManager.new
      # latest is 0 if there has not been a synchronization yet
      assert_equal(0, syncManager.latest(user, inverter.unique_id))
      csv_line1 = "#{syncTime.tv_sec},20,1000"
      sync(csv_line1)

      # check that there is an entry in the sync table after the first sync
      assert_equal(syncTime.tv_sec, syncManager.latest(user, inverter.unique_id))

      ims = Model::MeasurementChunk.find(:first, :conditions => ["device_id=?", inverter.id]);
      assert_equal(csv_line1, ims.data)

      # has the user's start_year been updated, too?
      assert_equal(Time.at(syncTime.tv_sec).utc.year, user.start_year)

      # we are only allowed to upload more recent data
      assert_raise(Model::SyncError) do
        sync("#{syncTime.tv_sec - 5},20,1000")
      end

      syncTime += 3600 # one hour later

      # sync the next chunk on the same day
      csv_line2 = "#{syncTime.tv_sec},0,1200"
      sync(csv_line2)

      assert_equal(syncTime.tv_sec, syncManager.latest(user, inverter.unique_id))

      ims = Model::MeasurementChunk.find(:first, :conditions => ["device_id=?", inverter.id]);
      assert_equal("#{csv_line1}\n#{csv_line2}", ims.data)

      # sync another chunk, this time containing data spanning two days
      syncTime = Time.utc(year, "jan", 6, 15, 0, 0)
      csv_line_day_6 = "#{syncTime.tv_sec},0,1300"
      syncTime = Time.utc(year, "jan", 7, 14, 0, 0)
      csv_line_day_7 = "#{syncTime.tv_sec},0,1400"
      sync("#{csv_line_day_6}\n#{csv_line_day_7}")

      # check data of day 6
      ims = Model::MeasurementChunk.find(:first, :conditions => ["time_year=? and time_day_of_year=?", year, 6]);
      assert_equal("#{csv_line_day_6}", ims.data)
      # check data of day 7
      ims = Model::MeasurementChunk.find(:first, :conditions => ["time_year=? and time_day_of_year=?", year, 7]);
      assert_equal("#{csv_line_day_7}", ims.data)
    end

    def test_sync_invalid_unique_id
      assert_raise(Model::SyncError) do
        Model::SyncManager.new.sync(user, "unkown", StringIO.new("1234,20,1000"))
      end
    end
  end
end