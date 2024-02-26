#!/bin/bash
# This script executes the migrations for the models in Postgres.

docker exec analytics /bin/bash -c "python manage.py makemigrations && python manage.py migrate --database postgres"
