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
require 'plantwatchdog/gems' # lock versions
require 'active_record'

#require 'benchmark'

#this fixes the AR Logger hack that annoys me sooooo much
class Logger
  private
  def format_message(severity, datetime, progname, msg)
    (@formatter || @default_formatter).call(severity, datetime, progname, msg)
  end
end

ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::DEBUG

module ActiveRecord
  class BaseWithoutTable < Base
    self.abstract_class = true
    def create_or_update
      errors.empty?
    end

    def == other
      return false if other.class != self.class
      attributes.values.eql?(other.attributes.values)
    end

    def hash
      attributes.values.hash
    end

    class << self
      def columns()
        @columns ||= []
      end

      def column(name, sql_type = nil, default = nil, null = true)
        columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
        reset_column_information
      end

      # Do not reset @columns
      def reset_column_information
        generated_methods.each { |name| undef_method(name) }
        @column_names = @columns_hash = @content_columns = @dynamic_methods_hash = @read_methods = nil
      end
    end
  end
end

module PlantWatchdog
  module Model
    class Schema<ActiveRecord::Migration
      def self.up

        create_table :users do |t|
          t.column :id, :integer # prim key
          t.column :timezone, :string # for converting UTC to local time
          t.column :password, :string
          t.column :name, :string
          # *_year is a performance optimization: it is used from the UI to find the years
          # for which there is data avalailable.
          # it could always be restored by looking at the available measurement_chunks
          t.column :start_year, :integer
          t.column :end_year, :integer
        end

        create_table :plants do |t|
          t.column :id, :integer # prim key
          t.column :user_id, :integer # foreign key
          t.column :aggregationrule_id, :integer # foreign key
        end

        # single table inheritance: inverter and sunmeter are devices
        create_table :devices do |t|
          t.column :type, :text # single table inheritance
          t.column :plant_id, :integer # foreign key
          t.column :aggregationrule_id, :integer # foreign key
          t.column :metadata_id, :integer # foreign key
          t.column :name, :string
          # the unique id is needed for the synchronization in order to assign measurements to a device
          # an example for a unique would be the serial number of an inverter
          t.column :unique_id, :string
        end

        create_table :measurement_chunks do |t|
          t.column :type, :text # for single table inheritance
          t.column :device_id, :integer
          t.column :plant_id, :integer # a Measurement Aggregate can belong to a plant instead of a device

          # the day on which data was collected according to local time
          t.column :time_year, :integer
          t.column :time_day_of_year, :integer

          t.column :data, :text, :limit => 16000000 # raw csv, limit to 16MB
          t.column :metadata_id, :integer # description of the columns of data
        end

        # metadata, used for describing the content of measurements and for describing aggregation rules
        # description must not be altered. Instead, create new records
        # whenever the column description changes
        create_table :metadata do |t|
          t.column :description, :string # serialized representation (JSON)
        end

        # performance only, could be retrieved by scanning the measurements table
        create_table :syncs do |t|
          t.column :user_id, :integer # foreign key
          t.column :device_id, :integer
          t.column :last_time, :integer # utc, epoch secs
        end

      end # self.up

      def self.down
        drop_table :syncs
        drop_table :devices
        drop_table :plants
        drop_table :users
        drop_table :measurement_chunks
        drop_table :metadata
      end
    end

    class User<ActiveRecord::Base
      # environment_measurements is supposed to contain a lot of data so we do
      # not want to have it O/R mapped
      #has_many :environment_measurements
      has_one :plant
      has_many :syncs
      def data_updated time_year
        new_start_year = time_year if start_year.nil?  or time_year < start_year
        new_end_year = time_year if end_year.nil? or time_year > end_year
        if (new_start_year or new_end_year)
          self.start_year = new_start_year if new_start_year
          self.end_year = new_end_year if new_end_year
          p save
        end
      end
    end

    module MetadataOwner
      def meta=(array)
        return if metadata and metadata.description == array
        self.metadata = Metadata.new
        metadata.description = array
      end

      def meta
        metadata.description
      end
    end

    module AggregationRuleOwner
      # set a dictionary defining the aggregation rules
      # dict-keys are the names of the resulting columns
      # dict-values defines the aggregation, the first entry is the name of the agg function, following (optional)
      # are parameters for the function
      def aggrules=(dict)
        return if aggregationrule and aggregationrule.description == dict
        self.aggregationrule = Metadata.new
        self.aggregationrule.description = dict
      end

      def aggrules
        self.aggregationrule ? self.aggregationrule.description : {};
      end
    end

    class Plant<ActiveRecord::Base
      has_many :devices
      belongs_to :user
      belongs_to :aggregationrule, :class_name => 'Metadata'
      include AggregationRuleOwner
    end

    class Device<ActiveRecord::Base
      belongs_to :plant
      belongs_to :aggregationrule, :class_name => 'Metadata'
      has_one :sync
      belongs_to :metadata#, :autosave => :true
      include MetadataOwner
      include AggregationRuleOwner
    end

    module MeasurementClassExtension
      def metadata
        @metadata
      end

      def metadata= m
        @metadata = m
      end
    end

    class Measurement < ActiveRecord::BaseWithoutTable

      column :time_year, :integer
      column :time_day_of_year, :integer
      column :time_seconds_of_day, :integer
      extend MeasurementClassExtension
      # set from a time object and split into
      # year, day of year and seconds of day
      # time t: seconds since epoch in utc
      def time= epoch_secs
        t = Time.at(epoch_secs.to_i) # this is local time, mind to set ENV["TZ"]
        write_attribute(:time_year, t.year)
        write_attribute(:time_day_of_year, t.yday)
        write_attribute(:time_seconds_of_day, t.sec + t.min*60 + t.hour*3600)
        write_attribute("time", epoch_secs)
      end

      def time
        t = read_attribute("time")
        return t if t
        t = Time.utc(time_year) + ((time_day_of_year-1)*3600*24) + time_seconds_of_day
        return t.tv_sec
      end

      def line= original_line
        @line= original_line
      end

      def line
        @line = to_csv unless @line
        @line
      end

      def to_csv
        meta = self.class.metadata.description
        logger.debug "to_csv, using metadata " + meta.to_s
        result = meta.collect { | coldesc | self[coldesc.first].to_s }.join(",")
        logger.debug "to_csv, result " + result
        result
      end

      # create a list of Measurement instances from csv lines
      # clazz is a sublass of Measurement
      # csv must understand readlines, eg. be an instance of IO or StringIO
      # the first column is a time column, other columns are defined by fields
      def self.from_CSV clazz, fields, csv
        # already converted ?
        return csv if csv.class == Array
        result = []
        return result if csv.nil?
        csv.each {
          |l|
          v = l.split(",")
          m = clazz.new
          m.line = l.chomp
          fields.each_index {|i| m.send(fields[i], v[i])}
          result << m
        }
        return result
      end

      def self.to_csv measurements
        measurements.collect { |m| m.line }.join "\n"
      end

      def self.parse_csv metadata, csv
        setters = metadata.dataclass.columns.collect{ |col| (col.name + "=").to_sym }
        result = self.from_CSV metadata.dataclass, setters, csv
        logger.debug "Read #{result.size} environment measurement entries from CSV"
        result
      end

      def self.partition_by_day measurements
        # assuming measurements is a list of measurements sorted by time
        result = {}
        # Gruppenwechsel in time_day_of_year
        changes = (1..measurements.size-1).select { |i| measurements[i-1].time_day_of_year != measurements[i].time_day_of_year }
        changes << measurements.size unless measurements.empty?
        changes.inject(0) { |s,e|
          m = measurements[s];
          # a hack to dismiss data which has been tagged with year 2000 which is the default
          # for a fritz!box before it has polled the time from a ntp server
          result[[m.time_year, m.time_day_of_year]] = measurements.slice(s,e-s) if m.time_year>2000;
          e
        }
        return result
      end

    end

    class AbstractMeasurementChunk < ActiveRecord::Base
      set_table_name :measurement_chunks
      serialize :data # MeasurementAggregate saves data as hash

      belongs_to :device

      belongs_to :metadata#, :autosave => :true
      include MetadataOwner
    end

    class MeasurementChunk < AbstractMeasurementChunk
      def measurements
        @measurements = Model::Measurement.parse_csv(metadata, data) unless @measurements
        @measurements
      end

      def append_measurements new_measurements
        # new_measurements are supposed to be taken at the same day as the existing data
        logger.debug("Appending #{new_measurements.size} measurement(s).")
        logger.debug(measurements)
        self.measurements = measurements | new_measurements
      end

      def measurements= new_measurements
        # all measurements are supposed to be from one day
        return if new_measurements.size == 0
        logger.debug("Setting #{new_measurements.size} measurement(s) for #{time_year}-#{time_day_of_year}.")
        @measurements = new_measurements
        self.data = Measurement.to_csv(new_measurements)
        device.plant.user.data_updated time_year
      end

      def self.save_measurements device, measurements
        return if measurements.empty?
        Measurement.partition_by_day(measurements).each_pair {
          | key, measurements |
          chunk = MeasurementChunk.find(:first, :conditions => ["device_id=? and time_year=? and time_day_of_year=?", device.id, key.first, key.last] )
          if chunk.nil? then
            chunk = MeasurementChunk.new
            chunk.device = device
            chunk.metadata = device.metadata
            chunk.time_year = key.first
            chunk.time_day_of_year =  key.last
          end
          chunk.append_measurements(measurements)
          chunk.save
        }
      end
    end

    class MeasurementAggregate < AbstractMeasurementChunk
      belongs_to :plant
    end

    class Metadata < ActiveRecord::Base
      set_table_name :metadata
      has_one :device
      #has_one :plant
      @@description_to_dataclass = {}

      def dataclass
        logger.debug "Accessing dataclass for metadata " + description.to_s
        if ! @@description_to_dataclass.has_key? description then
          logger.debug "Creating new dataclass for metadata " + description.to_s
          dataclass = Class.new(Model::Measurement)
          description.each { |args| dataclass.column *args }
          logger.debug dataclass.class
          dataclass.metadata = self
          @@description_to_dataclass[description] = dataclass
        end
        @@description_to_dataclass[description]
      end

      def description
        serialized = read_attribute("description")
        ActiveSupport::JSON.decode(serialized) unless serialized.nil?
      end

      def description=(arg)
        # the description is immutable
        # once an instance of metadata has been saved, no update is allowed
        raise "description is immutable" if read_attribute("description")
        serialized = arg
        serialized = ActiveSupport::JSON.encode(serialized) unless serialized.is_a? String
        write_attribute("description",serialized)
      end

    end

    class SyncError < StandardError
    end

    class SyncManager
      def sync(user, device_unique_id, csv)
        # assuming that csv is a timeseries, i.e. ordered by time
        device = device(user, device_unique_id)
        data = Measurement.parse_csv(device.metadata, csv)
        if (data.size == 0)
          logger.info "The data received from user #{user.name} (id=#{user.id}) is invalid, either it is empty or can not be parsed"
          return data.size
        end
        sync = device.sync
        unless sync
          logger.info "Creating new sync for user '#{user.name}' and  device unique id '#{device_unique_id}'"
          sync = Sync.new
          sync.device = device
          sync.last_time = 0
        end
        if (data.first.time <= sync.last_time)
          raise SyncError.new("The period is already sync'ed.")
        end
        MeasurementChunk.save_measurements(device, data)
        sync.last_time = data.last.time
        sync.save
        return data.size
      end

      def device(user, device_unique_id)
        raise SyncError.new("The user must create a plant and devices before uploading data") if user.plant.nil?
        devices = user.plant.devices.select { |i| i.unique_id == device_unique_id }
        raise SyncError.new("Could not identify device '#{device_unique_id}' of user '#{user.name}'. Found '#{devices.size}' devices.") if devices.size != 1
        device = devices.first
      end

      def latest(user, device_unique_id)
        device = device(user, device_unique_id)
        device.sync ? device.sync.last_time : 0;
      end

      def logger
        return ActiveRecord::Base.logger
      end
    end

    class Sync<ActiveRecord::Base
      belongs_to :user
      belongs_to :device
    end

  end
end