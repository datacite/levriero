#!/bin/sh
dockerize -template /home/app/webapp/vendor/docker/nginx.conf.tmpl:/etc/nginx/nginx.conf
dockerize -template /home/app/webapp/vendor/docker/jvm.options:/usr/share/elasticsearch-5.6.4/config/jvm.options
