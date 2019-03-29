#!/usr/bin/env bash

docker-compose down

rm -rf vault/ liquibase.properties oracleConfig.properties rest_webservice.properties ./.runbatch ./vault.initialization.out