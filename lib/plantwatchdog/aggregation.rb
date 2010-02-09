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
require 'plantwatchdog/model'
require 'plantwatchdog/aggregation_methods'

module PlantWatchdog
  # define the Aggregation Model,
  module Aggregation
    # the global environment to which the aggregation blocks have access
    class AggregationEnv
      logger = ActiveRecord::Base.logger
      attr_accessor :year, :day_of_year, :plant, :devices
      def initialize(year, day_of_year)
        @year = year
        @day_of_year = day_of_year
        @devices = []
      end

    end

    class Data
      # return the time series data for symbol
      def [] symbol

      end

      # return the list of seconds of the day for which there is data available
      def times
      end
    end

    module RuleEvaluation
      # data is an array of dictionaries, e.g. retrieved via Measurements.from_csv
      def eval_rule rule_array, data
        return 0 if rule_array.empty?
        method_name = rule_array.first
        arg_desc = rule_array[1, rule_array.size] # the column names for which we need to create time series
        args = arg_desc.collect { |arg_desc|
          if arg_desc.is_a? Numeric then
            arg_desc
          elsif arg_desc.is_a? Array
            eval_rule(arg_desc, data)
          else
            data.collect { |d| d[arg_desc] }
          end
        }
        return Methods.call(method_name, *args)
      end
    end

    class Device
      include RuleEvaluation
      def Device.create(model_device, year, day)
        # select data
        data = Model::MeasurementChunk.find(:first, :conditions => ["device_id=? and time_year=? and time_day_of_year=?", model_device.id, year, day])
        Device.new(model_device, data)
      end
      attr_accessor :model_device

      def initialize(model_device, data)
        @model_device = model_device
        @aggregates = {}
        @data = data
      end

      # generic access to the fields of the underlying model_device
      def not_understand
        # model_device
      end

      def measurements
        @data ? @data.measurements : []
      end

      def meta
        model_device.meta
      end

      # return the dict with aggregated values
      def aggregates

      end

      # execute the aggregation rules of the device
      def aggregate
        result = {}
        logger.debug "Aggregating device #{model_device.id}, aggrules: #{model_device.aggrules}"
        model_device.aggrules.each_pair do
          |agg_key, rule_array|
          result[agg_key] = eval_rule(rule_array, measurements)
        end
        logger.debug "Aggregation results: " + result.to_s
        result
      end

      def persist
        dm = Model::DailyMeasurement.new()
        dm.description = JSON(aggregates)
        return dm
      end

      # TODO: better way to access logger
      def logger
        return ActiveRecord::Base.logger
      end
    end

    class Plant
      include RuleEvaluation
      def initialize model_plant, device_aggregates
        @model_plant = model_plant
        @device_aggregates = device_aggregates
      end

      def aggregate
        result = {}
        logger.debug "Aggregating plant, aggrules: #{@model_plant.aggrules}"
        @model_plant.aggrules.each_pair do
          |agg_key, rule_array|
          result[agg_key] = eval_rule(rule_array,  @device_aggregates)
        end
        logger.debug "Aggregation results: " + result.to_s
        result
      end

      # TODO: better way to access logger
      def logger
        return ActiveRecord::Base.logger
      end

    end

    class Runner
      def find_missing_aggregates
        sql = <<EOF
      select time_year, time_day_of_year, plant_id from
      (select CHUNK.time_year, CHUNK.time_day_of_year, CHUNK.device_id AS device_id, AGG.device_id AS agg_device_id from
      ((select time_year, time_day_of_year, device_id from measurement_chunks where type="MeasurementChunk" order by time_year, time_day_of_year, device_id) AS CHUNK 
      LEFT OUTER JOIN
      (select time_year, time_day_of_year, device_id from measurement_chunks where type="MeasurementAggregate") AS AGG 
      ON CHUNK.time_year = AGG.time_year AND CHUNK.time_day_of_year=AGG.time_day_of_year AND CHUNK.device_id = AGG.device_id)
      where AGG.device_id IS NULL) AS MISSING
      INNER JOIN
      devices
      ON MISSING.device_id = devices.id
      GROUP BY MISSING.time_year, MISSING.time_day_of_year;    
EOF
        rows = ActiveRecord::Base.connection.select_all(sql)
        result = []
        rows.collect {
          |r|
          time_year = r["time_year"].to_i
          time_day_of_year = r["time_day_of_year"].to_i
          plant_id = r["plant_id"].to_i
          [time_year, time_day_of_year, plant_id]
        }
      end

      def run
        find_missing_aggregates.each {
          |m|
          time_year, time_day_of_year, plant_id = m
          aggregate(Model::Plant.find_by_id(plant_id), time_year, time_day_of_year)
        }
      end

      def aggregate(model_plant, year, day_of_year)
        env = AggregationEnv.new(year, day_of_year)
        model_plant.devices.each {
          |model_device|
          logger.debug("Adding device " + model_device.to_s)
          env.devices << Device.create(model_device, year, day_of_year)
        }
        # build the aggregates for the devices first ...
        aggregates = env.devices.collect do
          |device|
          daily = Model::MeasurementAggregate.new
          daily.device = device.model_device
          daily.time_year = year
          daily.time_day_of_year = day_of_year
          daily.data = device.aggregate
          daily
        end

        # ... and then aggregate the plant
        gen_aggregates = Plant.new(model_plant, aggregates.collect{|ma| ma.data}).aggregate

        gen_aggregate = Model::MeasurementAggregate.new
        gen_aggregate.data = gen_aggregates
        gen_aggregate.time_year = year
        gen_aggregate.time_day_of_year = day_of_year
        gen_aggregate.plant = model_plant

        # save when everything has been calculated
        aggregates << gen_aggregate
        aggregates.each {|a| a.save}
        aggregates
      end

      # TODO: better way to access logger
      def logger
        return ActiveRecord::Base.logger
      end

    end
  end
end