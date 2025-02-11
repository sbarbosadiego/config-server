#!/bin/bash

#PARAMETROS PARA BACKUP
HOJE="exemplo_"$(date +%d%m%y%H%M)
NOME="exemplo"
EXTENSAO=".bk"
EXTENSAO2=".tar.gz"
ARQUIVO=$NOME"_"$HOJE$EXTENSAO
PATH_BK="/exemplo/backup"
DATA=$(date +%m/%d/%yy) 


export PGPASSWORD=exemplo

if /usr/pgsql-14/bin/pg_dump -U postgres -p 8745 $NOME -Fc > $PATH_BK/$ARQUIVO
then


#GRAVANDO INFORMACOES NO BANCO DE DADOS
/usr/pgsql-14/bin/psql -U postgres -p 8745 $NOME -c "DELETE FROM backup"

/usr/pgsql-14/bin/psql -U postgres -p 8745 $NOME -c "INSERT INTO backup (data,enviado) VALUES (now(), false)"

else
#ERRO NA EXECUCAO DO BACKUP
exit 1
fi

#COMANDO PARA DELETAR BACKUPS ANTIGOS
ls -t "$PATH_BK" | tail -n +2 | xargs -I {} rm -f "$PATH_BK/{}"

exit 0