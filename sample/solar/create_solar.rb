$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'rubygems'
require 'plantwatchdog/model'
require 'active_record'
require 'active_record/fixtures'

module PlantWatchdog
  class CreateSolar
    def CreateSolar.create
      PlantWatchdog::Model::Schema.migrate(:up) unless ActiveRecord::Base.connection.table_exists? :users

      fixture_path = File.join(File.dirname(__FILE__),"static")
      p "Reading fixtures from #{fixture_path}"

      table_names = Dir["#{fixture_path}/*.yml"].map! { |f| File.basename(f).split('.').first.to_s }
      p "Found content for tables ", table_names.join(" ")
      class_names = table_names.inject({ :metadata => "PlantWatchdog::Model::Metadata"}) {
        |result, table_name|
        key= table_name.to_sym
        result[key] = "PlantWatchdog::Model::" + table_name.singularize.capitalize unless result[key]
        result
      }

      fs = Fixtures.create_fixtures(fixture_path, table_names, class_names)
    end
  end
end

#user =  PlantWatchdog::Model::User.find(:all).first
#p user.plant.aggrules
#p user.plant.devices.first.aggrules
