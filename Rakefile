# -*- ruby -*-
$:.unshift File.join(File.dirname(__FILE__),"lib")
require 'rubygems'
require 'hoe'
require 'plantwatchdog/main'

Hoe.spec 'plantwatchdog' do |p|
  developer('plantwatchdogteam', 'mbarchfe@rubyforge.org')
  p.version=PlantWatchdog::Version::STRING
  p.rubyforge_name = 'pwd'
  p.author = "Plantwatchdog team"
  p.email = "mbarchfe@rubyforge.org"
  p.summary = 'Plantwatchdog monitors your plant.'
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.extra_deps<<['sinatra','0.9.4']
  p.extra_deps<<['activerecord', '2.3.5']
  p.extra_deps<<['patir', '0.6.4']
  p.spec_extras={:executables=>["plantwatchdog","upload_measurements"],
    :default_executable=>"plantwatchdog"}
end
