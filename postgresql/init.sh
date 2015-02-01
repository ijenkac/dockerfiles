#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin

IP_ADDRESS="$(ip addr show eth0 | grep 'inet ' | awk '{ print $2 }' | cut -d '/' -f1)"
IP_SUBNET="$(echo $IP_ADDRESS | cut -d '.' -f1-3).0/16"

POSTGRES_BIN="/usr/lib/postgresql/${PG_VERSION}/bin/postgres"
POSTGRES_CONFIG="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"

if [ ! "$CREATE_DB" ]; then
    CREATE_DB="db"
fi

if [ ! -d "/var/lib/postgresql/${PG_VERSION}/main" ] ; then
    pg_createcluster ${PG_VERSION} main
    cat > "/etc/postgresql/${PG_VERSION}/main/pg_hba.conf" << EOF
local   all             postgres                                trust
host    all             all         $IP_SUBNET                  md5
EOF
    pg_ctlcluster ${PG_VERSION} main start
    password=${MASTER_PASSWORD:-$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 16)}
    psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$password';" &> /dev/null
    psql -U postgres -c "CREATE DATABASE $CREATE_DB;"

    pg_ctlcluster ${PG_VERSION} main stop

    echo "* Credentials: url=\"postgresql://postgres:${password}@${IP_ADDRESS}/$CREATE_DB\""
    exit 0
fi

su postgres -c "$POSTGRES_BIN -c config_file=\"$POSTGRES_CONFIG\" -c listen_addresses='*'"
