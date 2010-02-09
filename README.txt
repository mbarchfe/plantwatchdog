= Plant Watchdog

A watchdog for your technical plant, e.g. a photovoltaic generator. The plant
watchdog listens to data loggers, which continuously upload measurements of
plant parameters. Based on that data the watchdog creates reports about the
operational status.


== DESCRIPTION:

This software is being developed to monitor a photovoltaic generator. We found
that it would make sense to keep the domain specific knowledge out of the code
and instead provide a DSL to allow users to define their rules. Therefore this
software should be useful to monitor any kind of technical plant. 

At the time being the focus of development is to 
- make it reasonably stable 
- run per-day aggregations
- show intraday and monthly diagrams

With more data being available the task of finding deviations from regular 
operation is becoming feasible. Therefore expected values of parameters must
be calculated and compared with actual values: the users must be allowed to
define a model of the plant.

== FEATURES/PROBLEMS:

The vision of this software is to
 - allow data logger devices to continuously upload time series measurements
 - backup and distribute measurement data 
 - run user defined aggregations and analyses on the data
 - provide customizable HTML reports including visual diagrams
 - find deviations from regular operation and send alarms if necessary

== REQUIREMENTS:

* Ruby 1.8.7 and a database supported by active record, e.g. MySQL or SQLite

== INSTALL:

1. Install Ruby 1.8
For ubuntu 
  $ apt-get install ruby1.8-dev libopenssl-ruby1.8

2. Install a database
  Any database supported from active record should do, so far the server has
  been tested with MySql 5.1.14 and SQLite 3.6.21.
  
  In order to install sqlite3 and ruby bindings on ubuntu run
  $ apt-get install sqlite3-dev
  $ gem install sqlite3-ruby  
     
3. Install Plant Watchdog and required gems
  There are two options, either install the gem or download the sources from
  github. 
  A) gem 
  $ gem install plantwatchdog  
  
  B) github
  $ mkdir plant
  $ cd plant
  $ git clone git@github.com:mbarchfe/plantwatchdog.git
  $ rake check_extra_deps   // Get the required ruby gems
  
4. Install sample database and run
  If your gem's bin directory is not on the PATH, add it
  $ export PATH=$PATH:/var/lib/gems/1.8/bin
  
  The default database connection uses sqlite3 and a database at 
  /tmp/solarsample.sqlite3. You can change the default by editing
  the config file
  $ vi config/app-config.yaml
  
  Install the sample
  $ plantwatch --create_sample
  Upload data (needs curl and sqlite3 command line)
  
  Start the plantwatchdog web server (an alternative way is to start via rackup)
  $ plantwatchdog
  
  On another shell upload sample measurements. The script needs curl and the
  sqlite3 command line
  $ apt-get install curl
  $ upload_measurements
 
  Run the daily aggregation
  $ plantwatchdog -a

== LICENSE:

GPL v3