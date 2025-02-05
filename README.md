# Matomo for Embrapa I/O

Configuração de deploy do Matomo no ecossistema do Embrapa I/O.

Baseado no [repositório de configuração do Matomo no Docker](https://github.com/matomo-org/docker).

## Deploy

```
docker volume create matomo_db
docker volume create matomo_data
docker volume create --driver local --opt type=none --opt device=$(pwd)/backup --opt o=bind matomo_backup

cp .env.example .env

docker compose up --force-recreate --build --remove-orphans --wait
```

## Update

Antes do update, forçar um `archive`:

```
docker compose exec archive /usr/local/bin/php /app/console core:archive --url=https://hit.embrapa.io
```

Após o update, acertar as permissões dos arquivos:

```
docker compose exec matomo chown -R www-data:www-data /var/www/html/tmp
```

## Backup e Restore

Para restaurar um _dump_ do DB:

### Método 1: utilizando o _script_ da imagem de _auto-backup_

Veja a seção de _restore_ na [documentação da imagem de _auto-backup_](https://github.com/fradelg/docker-mysql-cron-backup). Em resumo, copie o _dump_ para o diretório `backup` e faça:

```
docker compose exec auto-backup /restore.sh /backup/dump.sql.gz
```

### Método 2: pelo cliente do MariaDB

Acesse o _console_ do container do banco de dados:

```
docker compose exec db bash
```

Em seguida, faça:

```
cd /backup

gzip -d dump.sql.gz

mariadb --database matomo --user root --password < /backup/dump.sql
```
