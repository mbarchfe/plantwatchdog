#!/bin/sh
# install the latest version of rdoc in order to overwrite the outdated internal version
# gem install rdoc
rdoc --title="Plantwatchdog's rdoc" --main=README.txt README.txt lib/plantwatchdog/aggregation_methods.rb 
