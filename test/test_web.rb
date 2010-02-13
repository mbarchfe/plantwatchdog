$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__),"..")
require 'rubygems'
require 'plantwatchdog/sinatra'
require 'plantwatchdog/aggregation'
require 'test/unit'
require 'rack/test'
require 'test/test_base'

module PlantWatchdog
  class TestSinatraApp < UI::SinatraApp
    set :environment, :test
  end
  
  class WebTest < Test::Unit::TestCase
    include TestUtil
    include Rack::Test::Methods
    
    def app
      TestSinatraApp
    end

    def prepare
      inverter = create_inverter
      sync("#{syncTime.tv_sec},20,#{etotal}")
      sync("#{syncTime.tv_sec+3600*24},20,#{etotal+1}")
    end

    def etotal
      1003
    end

    def syncTime
      Time.utc(2006, "jan", 20 , 12, 0, 0)
    end

    def test_available
      prepare
      get '/availabledata/2006'
      assert last_response.ok?
      assert_equal([{ "id" => 1, "label" => "1"}], ActiveSupport::JSON.decode( last_response.body ))
      get '/availabledata/2006/1'
      assert last_response.ok?
      assert_equal([{ "id" => 20, "label" => "20"},{ "id" => 21, "label" => "21"}], ActiveSupport::JSON.decode( last_response.body ))
    end

    def test_timeseries
      prepare
      get '/rawdata/2006/1/20'
      assert last_response.ok?
      ts = ActiveSupport::JSON.decode( last_response.body )
      assert_equal("123: etotal = 0", ts.first["label"])
      assert_equal(etotal, ts.first["data"][0][1])
    end

    def test_monthly_plant
      prepare
      gen = user.plant
      gen.aggrules = { "eday" => [:sum, "eday"] }
      gen.save!
      #Aggregation::Runner.new.run
      get '/monthly/plant/2006/1'
      ts = ActiveSupport::JSON.decode( last_response.body )
      assert last_response.ok?
      assert_equal(31, ts.first["data"].size)
    end

    def test_upload
      authorize user.name, user.password

      # the user has not created a device
      assert_raise(Model::SyncError) do
        get '/latestupload/device/123'
      end

      # user has not synced any data for the device
      inverter = create_inverter
      get '/latestupload/device/123'
      assert last_response.ok?
      assert_equal(0, last_response.body.to_i )

      put '/upload/device/123', "#{syncTime.tv_sec},20,#{etotal}"
      raise last_response.body unless last_response.ok?
      # now the user has synced once
      get '/latestupload/device/123'
      assert last_response.ok?
      assert_equal(syncTime.tv_sec, last_response.body.to_i )
    end
  end
end