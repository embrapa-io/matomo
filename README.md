# Matomo for Embrapa I/O

Configuração de deploy do Matomo no ecossistema do Embrapa I/O.

Baseado no [repositório de configuração do Matomo no Docker](https://github.com/matomo-org/docker).

## Troubleshooting

Em caso de erro de permissões no cache:

```
docker exec -it matomo-app-1 chown -R www-data:www-data /var/www/html/tmp
```
