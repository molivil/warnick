#!/bin/bash
mkdir -p ./sites
mkdir -p ./temp/pending
mkdir -p ./temp/complete
mkdir -p ./temp/published
mkdir -p ./temp/deleted
#mkdir -p ./temp/deleted/sites
chown -R www-data:www-data ./temp
chown -R www-data:www-data ./sites
chmod -R 770 ./temp
chmod -R 770 ./sites