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

class Array
  
  # Call the given block for every entry of the array and its predecessor.
  # The block is supposed to accept two parameters.
  # The block is not called at all if the array's length is less than two.
  #
  #  $ irb
  #  >> require 'plantwatchdog/aggregation_methods'
  #  => true
  #  >> [].each_prior{|x,y| x+y}
  #  => []
  #  >> [1].each_prior{|x,y| x+y}
  #  => []
  #  >> [1,2].each_prior{|x,y| x+y}
  #  => [3]
  #  >> [1,2,3].each_prior{|x,y| x+y}
  #  => [3, 5]
  def each_prior()
    i=0
    result=[]
    while (i < self.size-1) do
      result << yield(self[i],self[i+1])
      i+=1
    end
    return result
  end
end

module PlantWatchdog
  module Aggregation
    # This module contains those methods which can be referenced from
    # aggregation rules.
    module Methods
        
      # Calculate the difference between the last and first value of a list.
      # Useful to find the growth within a list of measurements where every
      # entry is already aggregated.
      #
      #  $ irb
      #  >> require 'plantwatchdog/aggregation_methods'
      #  >> include PlantWatchdog::Aggregation::Methods
      #  >> growth([])
      #  => 0
      #  >> growth([1])
      #  => 0
      #  >> growth([1,2])
      #  => 1
      #  >> growth([1,2,3])
      #  => 2
      def growth timeseries
        return 0 if timeseries.empty?
        timeseries.last - timeseries.first
      end

      # The average of a timeseries.
      #
      #  $ irb
      #  >> require 'plantwatchdog/aggregation_methods'
      #  >> include PlantWatchdog::Aggregation::Methods
      #  >> avg([])
      #  => NaN
      #  >> avg([1])
      #  => 1.0
      #  >> avg([1,2])
      #  => 1.5
      #  >> avg([1,2,3])
      #  => 2.0
      def avg timeseries
        result = sum(timeseries)
        result.to_f / timeseries.size
      end

      # Integrate the values over time.
      #
      #  $ irb
      #  >> require 'plantwatchdog/aggregation_methods'
      #  >> include PlantWatchdog::Aggregation::Methods
      #  >> integrate([],[])
      #  => 0
      #  >> integrate([0],[0])
      #  => 0
      #  >> integrate([0,1],[0,1])
      #  => 0.5
      #  >> integrate([0,2],[0,2])
      #  => 2.0
      #  >> integrate([0,1,2],[0,1,2])
      #  => 2.0
      #  >> integrate([0,1,2],[1,2,3])
      #  => 4.0
      def integrate times, values
        return [times.each_prior {|x,y| y-x}, values.each_prior {|x,y| (y+x)/2.0}].transpose.inject(0) {|i,a| i + a.first * a.last }
      end

      # Sum up all entries of an array which can contain nil values.
      #
      #  $ irb
      #  >> require 'plantwatchdog/aggregation_methods'
      #  >> include PlantWatchdog::Aggregation::Methods
      #  >> sum([])
      #  => 0
      #  >> sum([1])
      #  => 1
      #  >> sum([1,nil])
      #  => 1
      #  >> sum([1,2])
      #  => 3
      def sum timeseries
        timeseries.inject(0) { |a,v| v.nil? ? a : a += v }
      end

      # The product of two numbers
      def mult a,b
        a*b
      end

      # The ratio of two numbers.
      def div a,b
        a/b
      end

      # The difference between two numbers.
      def subtract a,b
        a - b
      end

      # The sum of two numbers
      def add a,b
        a + b
      end

      # Pick the n_th_ entry out of array a.
      def pick n,a
        a[n]
      end
      
      # Call aggregation method _method_ with arguments
      def call(method, *args)
        begin
          m = self.method method
          m.call *args
        rescue
          logger.debug("Error calling method '#{method}': " + $!.to_s)
          nil
        end
      end

      private
      def logger
        return ActiveRecord::Base.logger
      end
    end
  end
end