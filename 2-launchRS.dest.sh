#!/bin/bash
# Deploys and initiates a multi-node replica set on localhost
# to act as the destination for mongosync.

source demo.conf

USAGE="USAGE: launchRS.sh <node-count|1>"

node_count=${1:-1}
if ! [[ "$node_count" =~ ^[0-9]+$ ]]; then
  echo "$USAGE"
  exit 1
fi
if [ "$node_count" -gt 7 ]; then
  echo "$node_count MDB processes seems unreasonable. 7 max."
  echo "$USAGE"
  exit 1
fi

echo "Launching $node_count MDB processes ..."
echo

db_port=$BASE_MDB_PORT_DEST
initiateRS_stmt="rs.initiate( { _id: '$RS_NAME', members: ["

nodeID=0;
for (( i=1; i<=$node_count; i++ ))
do 
  echo "Launching MDB$i on port $db_port..."

  db_path=$BASE_DB_PATH/dest/db$db_port
  mkdir -p $db_path

  # 0.25 is the minimum wiredTigerCacheSizeGB
  set -x
  mongod --fork --port $db_port --dbpath $db_path --logpath $db_path/mongo$db_port.log --wiredTigerCacheSizeGB 0.25 --replSet "$RS_NAME"
  set +x

  # Add instance to the rs.initiate statement.
  if [ "$nodeID" -gt 0 ]; then
    # Adds a comma to separate RS hosts
    initiateRS_stmt="$initiateRS_stmt,"
  fi
  initiateRS_stmt="$initiateRS_stmt { _id:$nodeID, host: 'localhost:$db_port' }"

  ((db_port++))
  ((nodeID++))
  echo

done

echo "Initiating Replica Set ..."

# Finalize initiate statement
initiateRS_stmt="$initiateRS_stmt ]})"
echo $initiateRS_stmt
echo

mongosh --quiet --port $BASE_MDB_PORT_DEST --eval "$initiateRS_stmt"

# Configures the MDB_URI to connect to the replica set.
# The value is stored to demo.conf and picked up by subsequent scripts.

port=$BASE_MDB_PORT_DEST
MDB_URI="mongodb://"
for (( rsCounter=0; rsCounter<$node_count; rsCounter++ ))
do
  if [ "$rsCounter" -gt 0 ]; then
    # Adds a comma to separate RS hosts
    MDB_URI="$MDB_URI,"
  fi
  MDB_URI="${MDB_URI}localhost:$port"
  ((port++))
done
MDB_URI="$MDB_URI/?replicaSet=$RS_NAME"

# Writes the MDB_URI to demo.conf
sed -i '' "s|^MDB_URI_DEST.*|MDB_URI_DEST=$MDB_URI|g" demo.conf

# Writes the Node Count to demo.conf
sed -i '' "s|^NODE_COUNT_DEST.*|NODE_COUNT_DEST=$node_count|g" demo.conf

echo
echo "demo.conf updated."
echo "MDB_URI_DEST set to $MDB_URI"
echo "NODE_COUNT_DEST set to $node_count"
echo

