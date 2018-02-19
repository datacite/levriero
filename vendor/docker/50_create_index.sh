#!/bin/sh
/sbin/setuser app bundle exec rake elasticsearch:provider:create_index
/sbin/setuser app bundle exec rake elasticsearch:provider:import
/sbin/setuser app bundle exec rake elasticsearch:client:create_index
/sbin/setuser app bundle exec rake elasticsearch:client:import
