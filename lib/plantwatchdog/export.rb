# write csv measurement chunks into filesystem
# cd lib; ruby plantwatchdog/export.rb
require 'rubygems'
require 'plantwatchdog/model'
require 'active_record'
require 'active_record/fixtures'

require 'plantwatchdog/db'
require 'patir/base'

logger=Patir.setup_logger
config=YAML.load(File.read("../config/app_config.yaml"))
config[:logger]=logger
extend PlantWatchdog::ActiveRecordConnections
self.connect_to_active_record(config[:database_configuration],logger)

ms  = PlantWatchdog::Model::MeasurementChunk.find(:all)
ms.each { |m|
 p "writing #{m.time_year}/#{m.time_day_of_year}/#{m.device.unique_id}.csv"
 FileUtils.makedirs "#{m.time_year}/#{m.time_day_of_year}"
 f=File.new("#{m.time_year}/#{m.time_day_of_year}/#{m.device.unique_id}.csv","w")
 f.write(m.data)
 f.close
}

