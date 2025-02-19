#!/bin/bash

PG_VERSAO="14"
DB_NOME="base"
DB_PORTA="porta"
DB_USUARIO="postgres"

# Verifica distribuicao linux utilizada
validar_Distro() {    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" =~ ^(rocky|almalinux|rhel)$ && "$VERSION_ID" =~ ^8 ]]; then
            echo "Distro compatível: $PRETTY_NAME"
        else
            echo "Distro incompatível com o script"
            exit 1
        fi
    else
        echo "Não foi possível determinar a distro. O arquivo /etc/os-release não foi encontrado."
        exit 1
    fi
}

# Verifica se existe a particao /dados
verificar_particao() {
    if mount | grep -q " on /dados "; then
        echo "Partição /dados encontrada."
    else
        echo "Partição /dados não encontrada."
        exit 1
    fi
}

# Instalacao Postgres
instalar_Postgres() {
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    dnf -qy module disable postgresql
    dnf install postgresql$PG_VERSAO-server -y
    dnf install postgresql$PG_VERSAO-contrib -y
}

# Configura o diretorio que vai ser salvo o banco de dados
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
    sudo systemctl start postgresql-${PG_VERSAO}
}

# Realiza o tuning do banco de dados
tuning_Postgres() {
    local config_file="/dados/pgsql/$PG_VERSAO/data/postgresql.conf"

    # Verifica se o arquivo existe
    if [ -f "$config_file" ]; then
        # Executa os comandos como usuário postgres
        sudo -u postgres bash -c "
            sed -i \"s|^#\\?datestyle = .*|datestyle = 'iso, mdy'|\" \"$config_file\"
            sed -i \"s|^#\\?standard_conforming_strings = .*|standard_conforming_strings = off|\" \"$config_file\"
            sed -i \"s|^#\\?listen_addresses = .*|listen_addresses = '*'|\" \"$config_file\"
            sed -i \"s|^#\\?port = .*|port = 8745|\" \"$config_file\"
            sed -i \"s|^#\\?tcp_keepalives_idle = .*|tcp_keepalives_idle = 10|\" \"$config_file\"
            sed -i \"s|^#\\?tcp_keepalives_interval = .*|tcp_keepalives_interval = 10|\" \"$config_file\"
            sed -i \"s|^#\\?tcp_keepalives_count = .*|tcp_keepalives_count = 10|\" \"$config_file\"
            sed -i \"s|^#\\?log_destination = .*|log_destination = 'stderr'|\" \"$config_file\"
            sed -i \"s|^#\\?logging_collector = .*|logging_collector = off|\" \"$config_file\"
            sed -i \"s|^#\\?log_directory = .*|log_directory = 'log'|\" \"$config_file\"
            sed -i \"s|^#\\?log_rotation_age = .*|log_rotation_age = 1d|\" \"$config_file\"
            sed -i \"s|^#\\?log_filename = .*|log_filename = 'postgresql-%a.log'|\" \"$config_file\"
            sed -i \"s|^#\\?log_rotation_size = .*|log_rotation_size = 20MB|\" \"$config_file\"
            sed -i \"s|^#\\?log_truncate_on_rotation = .*|log_truncate_on_rotation = on|\" \"$config_file\"
            sed -i \"s|^#\\?enable_seqscan = .*|enable_seqscan = on|\" \"$config_file\"
            sed -i \"s|^#\\?enable_partitionwise_join = .*|enable_partitionwise_join = on|\" \"$config_file\"
            sed -i \"s|^#\\?enable_partitionwise_aggregate = .*|enable_partitionwise_aggregate = on|\" \"$config_file\"
            sed -i \"s|^#\\?password_encryption = .*|password_encryption = md5|\" \"$config_file\"
            sed -i \"s|^#\\?default_statistics_target = .*|default_statistics_target = 1000|\" \"$config_file\"
        "
        echo "Configurações de tuning aplicadas com sucesso no arquivo $config_file."
    else
        echo "Arquivo $config_file não encontrado. Verifique se o PostgreSQL foi inicializado corretamente."
        exit 1
    fi
}

configurar_Autenticacao() {
    local config_file="/dados/pgsql/$PG_VERSAO/data/pg_hba.conf"

    # Verifica se o arquivo existe
    if [ -f "$config_file" ]; then
        # Executa os comandos como usuário postgres
        sudo -u postgres bash -c "
            sed -i 's|^local[[:space:]]\+all[[:space:]]\+all[[:space:]]\+peer$|local   all             all                                     trust|' \"$config_file\"
            sed -i 's|^host[[:space:]]\+all[[:space:]]\+all[[:space:]]\+127\.0\.0\.1/32[[:space:]]\+md5$|host    all             all             127.0.0.1/32            trust|' \"$config_file\"
        "
        echo "Configuração de autenticação alterada para 'trust' no arquivo $config_file."
    else
        echo "Arquivo $config_file não encontrado. Verifique se o PostgreSQL foi inicializado corretamente."
        exit 1
    fi
}

# Funcao para instalar alguns aplicativos uteis na manutencao do servidor
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

# Configura um diretorio com todos os scripts que podem ser utilizados no servidor
configurar_Scripts(){
    cd /
    mkdir util
    chmod 777 -R util/
    cd util
    wget -c https://raw.githubusercontent.com/sbarbosadiego/config-server/refs/heads/main/scriptPgAmCheck.sh
    wget -c https://raw.githubusercontent.com/sbarbosadiego/config-server/refs/heads/main/scriptDump.sh
    wget -c https://raw.githubusercontent.com/sbarbosadiego/config-server/refs/heads/main/scriptVacuum.sh
    wget -c https://raw.githubusercontent.com/sbarbosadiego/config-server/refs/heads/main/scriptReindex.sh    
    wget -c https://raw.githubusercontent.com/sbarbosadiego/config-server/refs/heads/main/scriptVacuumReindex.sh
    wget -c https://raw.githubusercontent.com/sbarbosadiego/config-server/refs/heads/main/scriptBackup.sh
    chmod +x scriptDump.sh scriptPgAmCheck.sh scriptVacuum.sh scriptReindex.sh scriptVacuumReindex.sh scriptBackup.sh
}

criar_Base() {
    # Verifica se o PostgreSQL está rodando e se o banco já existe
    if ! sudo -u postgres psql -h 127.0.0.1 -p "$DB_PORTA" -lqt | cut -d \| -f 1 | grep -qw "$DB_NOME"; then
        # Cria o banco de dados
        sudo -u postgres psql -h 127.0.0.1 -p "$DB_PORTA" -c "CREATE DATABASE $DB_NOME;"
        echo "Banco de dados '$DB_NOME' criado com sucesso."
    else
        echo "O banco de dados '$DB_NOME' já existe."
    fi

    # Criação das roles e usuários
    sudo -u postgres psql -h 127.0.0.1 -p "$DB_PORTA" <<EOF
        ALTER USER postgres WITH ENCRYPTED PASSWORD 'VrPost@Server';
        CREATE ROLE pgsql LOGIN SUPERUSER INHERIT CREATEDB CREATEROLE REPLICATION;
        ALTER USER pgsql WITH ENCRYPTED PASSWORD 'VrPost@Server';
        CREATE ROLE controller360 LOGIN SUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
        CREATE USER desenvolvimento;
        CREATE USER implantacao;
        CREATE ROLE arcos;
        ALTER USER arcos WITH ENCRYPTED PASSWORD 'arcos';
        CREATE USER mercafacil;
        ALTER USER mercafacil WITH ENCRYPTED PASSWORD 'mercafacil';
        CREATE USER mixfiscal;
        ALTER USER mixfiscal WITH ENCRYPTED PASSWORD 'mixfiscal';
        CREATE USER pagpouco;
        ALTER USER pagpouco WITH ENCRYPTED PASSWORD 'pagpouco';
        CREATE USER simix;
        ALTER USER simix WITH ENCRYPTED PASSWORD 'simix';
        CREATE USER marketscience;
        ALTER USER marketscience WITH ENCRYPTED PASSWORD 'marketscience';
        CREATE USER berrytech;
        ALTER USER berrytech WITH ENCRYPTED PASSWORD 'berrytech';
        CREATE USER pricefy;
        ALTER USER pricefy WITH ENCRYPTED PASSWORD 'pricefy';
        CREATE USER webjasper;
        ALTER USER webjasper WITH ENCRYPTED PASSWORD 'webjasper';
        CREATE USER vr;
        CREATE USER smarket;
        ALTER USER smarket WITH ENCRYPTED PASSWORD 'smarket';
        CREATE USER upbackup;
        ALTER USER upbackup WITH ENCRYPTED PASSWORD 'upbackup';
        CREATE USER zbx_monitor WITH PASSWORD 'DB@m0nit0r' INHERIT;
        GRANT pg_monitor TO zbx_monitor;
EOF

    echo "Roles e usuários criados com sucesso no PostgreSQL."

    # Criando a extensão amcheck no banco
    sudo -u postgres psql -h 127.0.0.1 -p "$DB_PORTA" -d "$DB_NOME" -c "CREATE EXTENSION IF NOT EXISTS amcheck;"

    echo "Extensão amcheck criada com sucesso no banco '$DB_NOME'."
}

validar_Distro
verificar_particao
instalar_Utilitarios
instalar_Postgres
configurar_Postgres
tuning_Postgres
configurar_Autenticacao
configurar_Scripts
criar_Base
