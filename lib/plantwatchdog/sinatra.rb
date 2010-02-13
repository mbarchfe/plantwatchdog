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
require 'plantwatchdog/data'
require 'sinatra/base'
require 'erb'

module PlantWatchdog
  module UI
    # Reload scripts and reset routes on change
    class Sinatra::Reloader < Rack::Reloader
      def safe_load(file, mtime, stderr = $stderr)
        if file == __FILE__
          #::Sinatra::Application.reset!
          PlantWatchdog::UI::SinatraApp.reset!
          stderr.puts "#{self.class}: reseting routes"
        end
        super
      end
    end

    class SinatraApp < Sinatra::Base
      enable :logging
      enable :run
      enable :static
      set :server, %w[thin mongrel webrick]
      set :port, 7000
      set :root, File.dirname(__FILE__)
      set :public, File.dirname(__FILE__) + '/../../public'
      set :views, File.dirname(__FILE__) + '/../../templates'
      # there are several places where RACK_ENV can be set, if using passenger
      # one place is the virtual host configuration or the directory configuration
      use Sinatra::Reloader if (not ENV['RACK_ENV'].nil?) && ENV['RACK_ENV'].to_sym == :development
      
      include PlantWatchdog::Datadetection
      
      enable :sessions
      
      # TODO: patir logger from config
      attr_accessor :log

      def initialize
        @log = Logger.new(STDERR)
      end
      
      helpers do
        def protected!
          response['WWW-Authenticate'] = %(Basic realm="Plant Watchdog") and \
          throw(:halt, [401, "Not authorized\n"]) and \
          return unless authorized?
        end

        def authorized?
          @auth ||=  Rack::Auth::Basic::Request.new(request.env)
          @auth.provided? && @auth.basic? && is_valid_user?(*@auth.credentials)
        end

        def is_valid_user? user,password
          session[:user]=Model::User.find(:first, :conditions => [ "name = ? and password = ?", user, password] )
        end
        
      end
      
      def graph_height
        request[:height] ? request[:height] : "450px"
      end
      
      def graph_width
        request[:width] ? request[:width] : "700px"
      end
    
      get '/rawdata/:year/:month/:day' do
        year = params[:year].to_i
        month = params[:month].to_i
        day = params[:day].to_i
        yday = Time.utc(year,month,day).yday
        
        content_type "text/json"
        flot_series = []
        user.plant.devices.each {
          |device|
          ts = time_series(device, year, yday)
          ts.keys.sort.each {
            |key|
            # TODO: allow to configure the axis-mapping
            flot_series <<  { :data=> ts[key], :label=> "#{device.unique_id}: #{key} = 0", :yaxis => key =~ /(etotal)|(temperature)/ ? 2 : 1 }
          }
        }
        return ActiveSupport::JSON.encode(flot_series)
      end
      
      include PlantWatchdog::Monthhelper
      get '/monthly/plant/:year/:month' do
        year = params[:year].to_i
        month = params[:month].to_i
        content_type "text/json"
        flot_series = []
        days = days_of_month(year, month).collect{ |d| [year, d.yday] }
        plant_aggregates(user.plant, days).each_pair {
          |k,v|
          flot_series << { :data => v, :label => "#{k} = 0" }
        }
        return ActiveSupport::JSON.encode(flot_series)
      end
       
      # TODO: the final URI must contain the user id (or the plant id if several plants should be allowed)
      get "/availabledata/:year" do
        getAvailableData(params[:year])
      end
      
      get "/availabledata/:year/:month" do
       getAvailableData(params[:year],params[:month])
      end
      
      def getAvailableData(year, month=nil) 
        result = []
        if month.nil?
          getDayOfYearConverter(year).months().each {
            |m|
            result << { :id =>  m, :label => m.to_s }
          }
        elsif (not year.nil?) and not month.nil?
          getDayOfYearConverter(year).days(month.to_i).each {
            |d|
            result << { :id => d, :label => d.to_s }
          }
        end
        ActiveSupport::JSON.encode result
      end

      def getDayOfYearConverter(year)
        result = session[year]
        if result.nil?
          throw "invalid state: getDayOfYearConverter must be called with year argument first" if year.nil?
          days = days_with_data(user, year)
          result = PlantWatchdog::DayOfYearConverter.new(year, days)
          p "adding DayOfYearConverter to session with key "+ year
          session[year]=result
        end
        result
      end

      get '/' do
        erb :index
      end
      
      get '/monthly_graph.html' do
        erb :monthly_graph
      end
      
      get '/graph.html' do
        erb :graph
      end

      def user
        # TODO: support multiple users
        Model::User.find( :first )
      end

      put '/upload/device/:unique_id' do
        upload(params[:unique_id])
      end
      
      def upload(unique_id)
        protected!
        begin
          return Model::SyncManager.new.sync(session[:user], unique_id, request.body).to_s
        rescue StandardError
           # the put method does not return a 404 page with the exception as the get method does
           log.error "Error uploading csv:"
           log.error $!.message
           log.error $!.backtrace
           status 500
           return $!.message  
        end
      end

      get '/latestupload/device/:serialnumber' do
        protected!
        Model::SyncManager.new.latest(session[:user], params[:serialnumber]).to_s
      end

    end
  end
end

class Sinatra::Application
  def self.run?
    return false
  end
end
