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
#redirect $0 because otherwise sinatra/main.rb tries to parse the command line
$0="plantwatchdog"
require 'plantwatchdog/sinatra'
require 'plantwatchdog/db'
require 'optparse'
require 'patir/base'
require 'yaml'

module PlantWatchdog
  module Version
    MAJOR=0
    MINOR=0
    TINY=1
    STRING=[ MAJOR, MINOR, TINY ].join( "." )
  end
  
  #Parses the command line arguments
  def self.parse_command_line args
    options = OpenStruct.new
    options.config_file = File.join(File.dirname(__FILE__),'..', '..', 'config', 'app_config.yaml')
    options.aggregate = false
    args.options do |opt|
      opt.on("Usage:")
      opt.on("plantwatchdog [options]")
      opt.on("Options:")
      opt.on("--debug", "-d","Turns on debug messages") { $DEBUG=true }
      opt.on("-v", "--version","Displays the version") { $stdout.puts("v#{Version::STRING}");exit 0 }
      opt.on("--config_file FILE", "-c FILE", "The config file") { |file| options.config_file = file }
      opt.on("--aggregate", "-a", "Run daily data aggregation") { options.aggregate = true }
      opt.on("--create_solar", nil, "Create database with sample data from a solar generator") { options.createsolar = true }
      opt.on("--help", "-h", "-?", "This text") { $stdout.puts opt; exit 0 }
      opt.parse!
    end
    options
  end
  #Starts App
  def self.start
    logger=Patir.setup_logger
    options=parse_command_line(ARGV)
    if File.exists?(options.config_file)
      config=YAML.load(File.read(options.config_file))
      config[:logger]=logger
    else
      logger.fatal("Cannot find #{options.config_file}")
      exit 1
    end
    extend PlantWatchdog::ActiveRecordConnections
    self.connect_to_active_record(config[:database_configuration],logger)
    if options.createsolar then
      $:.unshift File.join(File.dirname(__FILE__),"..","..")
      require 'sample/solar/create_solar'
      PlantWatchdog::CreateSolar.create
    elsif options.aggregate then
      require 'plantwatchdog/aggregation'
      Aggregation::Runner.new.run
    else
      PlantWatchdog::UI::SinatraApp.run!
    end
  end
end

PlantWatchdog.start