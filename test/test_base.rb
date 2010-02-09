$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'rubygems'

module PlantWatchdog
  module TestUtil
    def setup type=:sqlite
      type == :mysql ? setup_mysql : setup_sqlite
      #setup_sqlite
      #Model::Schema.migrate(:down)
      Model::Schema.migrate(:up)
    end

    def setup_sqlite
      ActiveRecord::Base.establish_connection(:adapter => "sqlite3",
      :database => ":memory:")
      #require 'ar-extensions/import/sqlite'
    end

    def setup_mysql
      ActiveRecord::Base.establish_connection(:adapter=>"mysql",
      :database => "solar",
      :username=>"root",
      :password=>"root"
      )

      #require 'ar-extensions/import/mysql'

    end

    def user
      user = Model::User.find(:first, :conditions => [ "name = 'markus'" ] )
      return user if user
      user = Model::User.new
      user.name = 'markus'
      user.password = 'markus'
      user.save()
      return user
    end

    def create_inverter(plant = nil)

      if (user.plant.nil?)
        plant = Model::Plant.new
        plant.user = user
        plant.save();
      end

      inverter = Model::Device.new
      inverter.plant = user.plant
      inverter.unique_id = "123"
      inverter.meta = [["time", "integer"], ["pac", "float"], ["etotal", "integer"]]
      inverter.save

      return inverter
    end

    def create_measurement(time, pac, etotal)
      metadata = user.plant.devices.first.metadata
      m = metadata.dataclass.new;
      m.time = time
      m.pac = pac
      m.etotal = etotal
      m
    end

    def sync(csv, inverter=user.plant.devices.first)
      Model::SyncManager.new.sync(user, inverter.unique_id, StringIO.new(csv))
    end

    def write_file(name, content)
      f = File.new("#{data_dir}#{name}", "w")
      f.write(content)
      f.close
    end

    def data_dir
      dirname = "#{File.dirname(__FILE__)}/unit_test_generated/"
      FileUtils.mkdir(dirname) unless File.exists?(dirname)
      dirname
    end

  end
end
