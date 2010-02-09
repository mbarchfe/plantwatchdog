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

module PlantWatchdog
  class ConnectionError<RuntimeError
  end

  module ActiveRecordConnections
    #Establishes an ActiveRecord connection
    def connect_to_active_record cfg,logger
      conn=connect(cfg,logger)
    end
    private
    #Establishes an active record connection using the cfg hash
    #There is only a rudimentary check to ensure the integrity of cfg
    def connect cfg,logger
      if cfg[:adapter] && cfg[:database]
        logger.debug("Connecting to #{cfg[:database]}")
        return ActiveRecord::Base.establish_connection(cfg)
      else
        raise ConnectionError,"Erroneous database configuration. Missing :adapter and/or :database"
      end
    end
  end
end