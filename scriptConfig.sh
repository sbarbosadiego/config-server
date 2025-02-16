#!/bin/bash

PG_VERSAO="14"

# Verifica distribuicao linux utilizada
validar_Distro() {    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" =~ ^(rocky|almalinux|rhel)$ && "$VERSION_ID" =~ ^8 ]]; then
            echo "✅ Distro compatível: $PRETTY_NAME"
        else
            echo "❌ Distro incompatível com o script"
            exit 1
        fi
    else
        echo "❌ Não foi possível determinar a distro. O arquivo /etc/os-release não foi encontrado."
        exit 1
    fi
}

# Verifica se existe a particao /dados
verificar_particao() {
    if mount | grep -q " on /dados "; then
        echo "✅ Partição /dados encontrada."
    else
        echo "❌ Partição /dados não encontrada."
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

validar_Distro
verificar_particao
instalar_Utilitarios
instalar_Postgres
configurar_Postgres
tuning_Postgres
configurar_Scripts
