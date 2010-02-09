# this is Rackup file. It is necessary for applications started from a container
# e.g. passenger, or via the rackup command.
require 'rubygems'
#this locks on the versions we need
require 'lib/plantwatchdog/gems'
require 'lib/plantwatchdog/sinatra.rb'
require 'lib/plantwatchdog/db.rb'
require 'yaml'
path = ''

set :root, path
set :views, path + '/views'
set :public,  path + '/public'
set :run, false
set :raise_errors, true

log = File.new("sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

logger=Logger.new(STDOUT)
logger.level = Logger::INFO

config_file="config/app_config.yaml"
if File.exists?(config_file)
      config=YAML.load(File.read(config_file))
      config[:logger]=logger
else
      logger.fatal("Cannot find #{config_file}")
      exit 1
end

extend PlantWatchdog::ActiveRecordConnections
self.connect_to_active_record(config[:database_configuration],logger)
run PlantWatchdog::UI::SinatraApp
