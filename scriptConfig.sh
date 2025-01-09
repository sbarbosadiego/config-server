#!/bin/bash

instalar_Utilitarios
instalar_Postgres

# Funcao Instalacao Postgres
instalar_Postgres() {
	dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
	dnf -qy module disable postgresql
	dnf install postgresql14-server -y
	dnf install postgresql14-contrib -y
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

configurar_scripts(){
	cd /
	mkdir util
	chmod 777 -R util/
	cd util
	#wget -c <scriptPgAmCheck>
	#wget -c <scriptVacuum>
	#wget -c <scriptReindex>	
	#wget -c <scriptVacuum_Reindex>
}
