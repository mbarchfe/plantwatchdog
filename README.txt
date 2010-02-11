= Plant Watchdog

http://wiki.github.com/mbarchfe/plantwatchdog

== DESCRIPTION:

A watchdog for your technical plant, e.g. a photovoltaic generator. The plant
watchdog listens to data loggers, which continuously upload measurements of
plant parameters. Based on that data the watchdog creates reports about the
operational status.

== FEATURES/PROBLEMS:

The vision of this software is to
* allow data logger devices to continuously upload time series measurements
* store and distribute measurement data 
* run user defined aggregations and analyses on the data
* provide customizable HTML reports including visual diagrams
* find deviations from regular operation and send alarms if necessary

== REQUIREMENTS:

* Ruby 1.8.7 and a database supported by active record, e.g. MySQL or SQLite

== INSTALL:

 gem install plantwatchdog

For more details see http://wiki.github.com/mbarchfe/plantwatchdog/installation.
In particular you will find a guide on how to set up a sample scenario.

== LICENSE:

GPL v3