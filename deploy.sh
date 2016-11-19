#!/bin/bash -ex

rm -f ./postgres_exporter

GOOS=linux GOARCH=386 make postgres_exporter

fwknop -s -n vocabincontext.danstutzman.com
scp -C ./postgres_exporter root@vocabincontext.danstutzman.com:/root/postgres_exporter

rm -f ./postgres_exporter

fwknop -s -n vocabincontext.danstutzman.com
ssh root@vocabincontext.danstutzman.com <<EOF
set -ex

id -u postgres_exporter &>/dev/null || sudo useradd postgres_exporter
sudo mkdir -p /home/postgres_exporter
sudo chown postgres_exporter:postgres_exporter /home/postgres_exporter

tee /etc/init/postgres_exporter.conf <<EOF2
start on started remote_syslog
setuid postgres_exporter
setgid postgres_exporter
script
  DATA_SOURCE_NAME=postgresql://vocabincontext:vocabincontext@localhost/postgres \\
    /home/postgres_exporter/postgres_exporter -web.listen-address :9113 \\
    -extend.query-path /home/postgres_exporter/queries.yaml
end script
EOF2

sudo -u postgres_exporter tee /home/postgres_exporter/queries.yaml <<EOF2
pg_stat_replication:
  query: select 1 where 1 = 0
EOF2

sudo service postgres_exporter stop || true
sudo mv /root/postgres_exporter /home/postgres_exporter/postgres_exporter
sudo chown postgres_exporter:postgres_exporter /home/postgres_exporter/postgres_exporter
sudo service postgres_exporter start

sleep 1
curl -f http://localhost:9113/metrics >/dev/null

sudo ufw allow from \$(dig +short monitoring.danstutzman.com) to any port 9113

EOF
