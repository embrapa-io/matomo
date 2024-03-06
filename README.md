# Matomo for Embrapa I/O

Configuração de deploy do Matomo no ecossistema do Embrapa I/O.

Baseado no [repositório de configuração do Matomo no Docker](https://github.com/matomo-org/docker).

## Update

Antes do update, forçar um `archive`:

```
docker exec -it matomo-archive-1 /usr/local/bin/php /app/console core:archive --url=https://hit.embrapa.io
```

Após o update, acertar as permissões dos arquivos:

```
docker exec -it matomo-app-1 chown -R www-data:www-data /var/www/html/tmp
```
