#!/usr/bin/env bash

figlet -f standard "Create containers for Vault, Oracle, and Tomcat"

rm -rf ./vault
mkdir ./vault
mkdir ./vault/config

cp vault.local.json ./vault/config/.

docker-compose up -d

echo "Waiting for Vault to start"
while true ; do
  result=$(docker logs vaultserver 2> /dev/null | grep -c "==> Vault server started! Log data will stream in below:")
  if [ $result = 1 ] ; then
    echo "Vault has started"
    break
  fi
  sleep 1
done

echo "Waiting for Oracle to start"
while true ; do
  curl -s localhost:8081 > tmp.txt
  result=$(grep -c "DOCTYPE HTML PUBLIC" tmp.txt)
  if [ $result = 1 ] ; then
    echo "Oracle has started"
    break
  fi
  sleep 1
done
rm tmp.txt

echo "Waiting for Tomcat to start"
while true ; do
  curl -s localhost:8080 > tmp.txt
  result=$(grep -c "Apache Tomcat/9.0.8" tmp.txt)
  if [ $result = 2 ] ; then
    echo "Tomcat has started"
    break
  fi
  sleep 1
done
rm tmp.txt

figlet -f standard "Provision Vault"
docker cp $(pwd)/vault.init.sh vaultserver:/vault.init.sh
docker exec vaultserver /vault.init.sh > vault.initialization.out
./vault.initialization.out.parse.sh

docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault operator unseal '$(< ./vault/UnsealKey1)
docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault operator unseal '$(< ./vault/UnsealKey2)
docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault operator unseal '$(< ./vault/UnsealKey3)

docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault login '$(< ./vault/InitialRootToken)

figlet -f standard "Write some secrets into Vault"

echo `date +%Y%m%d%H%M%S` > ./.runbatch
export RUNBATCH=$(echo `cat ./.runbatch`)

docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault secrets enable -version=2 -path=oracle kv'
docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault kv put oracle/dev/'$RUNBATCH'/username username=system'
docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault kv put oracle/dev/'$RUNBATCH'/password password=oracle'

docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault kv get oracle/dev/'$RUNBATCH'/username' | tee ./.temp
while read line
do
    echo "$line" | grep  "^username\ *.*$" | xargs | cut -d ' ' -f2 > ./.value
    if [ -s "./.value" ]
        then
            export ORACLE_USERNAME=$(< ./.value)
    fi
done < ./.temp
rm ./.value ./.temp

docker exec vaultserver /bin/sh -c 'export VAULT_ADDR="http://127.0.0.1:8200";vault kv get oracle/dev/'$RUNBATCH'/password' | tee ./.temp
while read line
do
    echo "$line" | grep  "^password\ *.*$" | xargs | cut -d ' ' -f2 > ./.value
    if [ -s "./.value" ]
        then
            export ORACLE_PASSWORD=$(< ./.value)
    fi
done < ./.temp
rm ./.value ./.temp

figlet -f standard "Create the Oracle database"

echo "Build the liquibase.properties file for Liquibase to run against"
echo "driver: oracle.jdbc.driver.OracleDriver" > liquibase.properties
echo "classpath: lib/ojdbc8.jar" >> liquibase.properties
echo "url: jdbc:oracle:thin:@"$(hostname)":1521:xe" >> liquibase.properties
echo "username: $ORACLE_USERNAME" >> liquibase.properties
echo "password: $ORACLE_PASSWORD" >> liquibase.properties

echo "Create database schema and load sample data"
liquibase --changeLogFile=src/main/db/changelog.xml update