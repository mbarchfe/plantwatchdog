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
    module Methods
      class << self
        def growth timeseries
          timeseries.last - timeseries.first
        end

        def avg timeseries
          result = sum(timeseries)
          result.to_f / timeseries.size
        end

        def integrate times, values
          return [times.each_prior {|x,y| y-x}, values.each_prior {|x,y| (y+x)/2.0}].transpose.inject(0) {|i,a| i + a.first * a.last }
        end

        def sum timeseries
          result = 0
          timeseries.each { |v| result += v if v}
          return result
        end

        def mult a,b
          a*b
        end

        def div a,b
          a/b
        end

        def subtract a,b
          a - b
        end

        def add
          a + b
        end

        def pick n,a
          a[n]
        end

        def call(method, *args)
          begin
            m = Methods.method method
            m.call *args
          rescue
            logger.debug("Error calling method '#{method}': " + $!.to_s)
            nil
          end
        end

        def logger
          return ActiveRecord::Base.logger
        end
      end

    end
  end
end