# Matomo for Embrapa I/O

Configuração de deploy do Matomo no ecossistema do Embrapa I/O.

Baseado no [repositório de configuração do Matomo no Docker](https://github.com/matomo-org/docker).

## Deploy

```
docker volume create matomo_db
docker volume create matomo_data
docker volume create --driver local --opt type=none --opt device=$(pwd)/backup --opt o=bind matomo_backup

cp .env.example .env

docker-compose up --force-recreate --build --remove-orphans --wait
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

Para restaurar um arquivo:

```
docker compose build --force-rm --no-cache backup

BACKUP_FILE_TO_RESTORE=matomo_2025-02-03_20-53-59.tar.gz docker compose run --rm --no-deps restore
```
