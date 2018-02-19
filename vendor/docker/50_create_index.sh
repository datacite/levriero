#!/bin/sh
/sbin/setuser app bundle exec rake elasticsearch:provider:import
/sbin/setuser app bundle exec rake elasticsearch:client:import
