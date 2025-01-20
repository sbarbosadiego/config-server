#!/bin/bash

PG_VERSAO="14"

# Funcao Instalacao Postgres
instalar_Postgres() {
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    dnf -qy module disable postgresql
    dnf install postgresql$PG_VERSAO-server -y
    dnf install postgresql$PG_VERSAO-contrib -y
}

# Funcao para configurar o diretorio que vai ser salvo o banco de dados
configurar_Postgres() {
    local service_file="/usr/lib/systemd/system/postgresql-${PG_VERSAO}.service"
    if [ -f "$service_file" ]; then
        # Modifica apenas a linha abaixo de "# Location of database directory"
        sed -i '/# Location of database directory/{n;s|.*|Environment=PGDATA=/dados/pgsql/14/data/|}' "$service_file"
        echo "Linha de PGDATA no arquivo $service_file foi atualizada com sucesso."
    else
        echo "Arquivo $service_file não encontrado. Verifique se o PostgreSQL $PG_VERSAO está instalado."
        exit 1
    fi
    
    sudo /usr/pgsql-${PG_VERSAO}/bin/postgresql-${PG_VERSAO}-setup initdb
    sudo systemctl enable postgresql-${PG_VERSAO}
}

tuning_Postgres() {
    local config_file="/dados/pgsql/$PG_VERSAO/data/postgresql.conf"

    # Verifica se o arquivo existe
    if [ -f "$config_file" ]; then
        # Executa os comandos como usuário postgres
        sudo -u postgres bash -c "
            sed -i '694s|.*|datestyle = '\''iso, mdy'\''|' \"$config_file\"
            sed -i '758s|.*|standard_conforming_strings = off|' \"$config_file\"
            sed -i '60s|.*|listen_addresses = '\''*'\''|' \"$config_file\"
            sed -i '64s|.*|port = 8745|' \"$config_file\"
            sed -i '80s|.*|tcp_keepalives_idle = 10|' \"$config_file\"
            sed -i '82s|.*|tcp_keepalives_interval = 10|' \"$config_file\"
            sed -i '84s|.*|tcp_keepalives_count = 10|' \"$config_file\"
            sed -i '433s|.*|log_destination = '\''stderr'\''|' \"$config_file\"
            sed -i '439s|.*|logging_collector = off|' \"$config_file\"
            sed -i '445s|.*|log_directory = '\''log'\''|' \"$config_file\"
            sed -i '451s|.*|log_rotation_age = 1d|' \"$config_file\"
            sed -i '447s|.*|log_filename = '\''postgresql-%a.log'\''|' \"$config_file\"
            sed -i '453s|.*|log_rotation_size = 20MB|' \"$config_file\"
            sed -i '456s|.*|log_truncate_on_rotation = on|' \"$config_file\"
            sed -i '378s|.*|enable_seqscan = on|' \"$config_file\"
            sed -i '376s|.*|enable_partitionwise_join = on|' \"$config_file\"
            sed -i '377s|.*|enable_partitionwise_aggregate = on|' \"$config_file\"
            sed -i '96s|.*|password_encryption = md5|' \"$config_file\"
            sed -i '416s|.*|default_statistics_target = 1000|' \"$config_file\"
        "
        echo "Configurações de tuning aplicadas com sucesso no arquivo $config_file."
    else
        echo "Arquivo $config_file não encontrado. Verifique se o PostgreSQL foi inicializado corretamente."
        exit 1
    fi
}


# Utilitarios
instalar_Utilitarios() {
    dnf install epel-release -y
    dnf install htop -y
    dnf install sendemail -y
    dnf install nmtui -y
    dnf install vim -y
    dnf install wget -y
    dnf install tmux -y
    dnf install smartmontools -y
    dnf update -y
}

configurar_Scripts(){
    cd /
    mkdir util
    chmod 777 -R util/
    cd util
    #wget -c <scriptPgAmCheck>
    #wget -c <scrptDump>
    #wget -c <scriptVacuum>
    #wget -c <scriptReindex>    
    #wget -c <scriptVacuum_Reindex>
}

instalar_Utilitarios
instalar_Postgres
configurar_Postgres
tuning_Postgres
configurar_Scripts
