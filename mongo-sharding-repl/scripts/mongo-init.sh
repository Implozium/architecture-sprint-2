#!/bin/bash

###
# Инициализируем бд
###

echo "Init configSrv";

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
    {
        _id : "config_server",
        configsvr: true,
        members: [
            { _id : 0, host : "configSrv:27017" }
        ]
    }
);
EOF

sleep 10;

echo "Init shard1";

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
        _id : "shard1",
        members: [
            { _id : 0, host : "shard1:27018" },
            { _id : 1, host : "shard1rep1:27021" },
            { _id : 2, host : "shard1rep2:27022" },
        ]
    }
);
EOF

echo "Init shard2";

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate(
    {
        _id : "shard2",
        members: [
            { _id : 0, host : "shard2:27019" },
            { _id : 1, host : "shard2rep1:27023" },
            { _id : 2, host : "shard2rep2:27024" },
        ]
    }
);
EOF

sleep 10;

echo "Init mongos_router";

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
EOF

echo "Add data";

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
EOF

echo "Test shard1";

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF

echo "Test shard2";

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF
