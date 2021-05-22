#!/bin/bash

echo "<<<<<<<<<<<<<<<<<<<<<"

# get postgres dockerid
# TODO k8s method
#namespace=`kubectl get pod -A |grep pos  | awk '{print $1 }' | awk 'NR=1' | head -1`
#podid=`kubectl get pod -A |grep pos  | awk '{print $2 }' | awk 'NR=1' | head -1`
#kubectl  exec -it  $podid -n $namespace -- sh -c  "rm -rf /home/modelsets.sql"
#kubectl  exec -it  $podid -n $namespace -- sh -c  "rm -rf /home/datasets.sql"
#kubectl cp modelsets.sql  $podid:/home/modelsets.sql -n $namespace
#kubectl cp datasets.sql  $podid:/home/datasets.sql -n $namespace
#kubectl  exec -it  $podid -n $namespace -- sh -c  "psql -d ai_arts -U postgres -f /home/modelsets.sql"
#kubectl  exec -it  $podid -n $namespace  -- sh -c   "psql -d ai_arts -U postgres -f /home/datasets.sql"

dockerid=$(docker ps | grep 'k8s_postgres_postgres' | awk '{print $1 }' | awk 'NR=1' | head -1)
docker cp ./preset_models.sql $dockerid:/home/
docker exec -it $dockerid /bin/bash -c "psql -d ai_arts -U postgres -f /home/preset_models.sql"


echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<"
echo "preset_models table data was inserted !"
echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<"

