#!/bin/bash

# Variável para a senha do postgres
export PGPASSWORD=Senha

/usr/pgsql-14/bin/psql -U postgres -p 8745 -d vr -c "REINDEX DATABASE base"