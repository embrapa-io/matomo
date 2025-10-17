# Matomo for Embrapa I/O

Configuração de deploy do Matomo no ecossistema do Embrapa I/O.

Baseado no [repositório de configuração do Matomo no Docker](https://github.com/matomo-org/docker).

## Deploy

Copie e ajuste o arquivo de configuração:

```bash
cp .env.example .env
```

Crie os volumes externos:

```bash
docker volume create matomo_db && \
docker volume create matomo_data && \
docker volume create --driver local --opt type=none --opt device=$(pwd)/backup --opt o=bind matomo_backup
```

> **Atenção!** Se for recuperar o _backup_, olhe na seção mais abaixo as instruções antes de subir a aplicação.

Suba a aplicação:

```bash
docker compose up --force-recreate --build --remove-orphans --wait
```

## Update

Antes do update, forçar um `archive`:

```bash
docker compose exec archive /usr/local/bin/php /app/console core:archive --url=https://hit.embrapa.io
```

Após o update, acertar as permissões dos arquivos:

```bash
docker compose exec matomo chown -R www-data:www-data /var/www/html
```

## Backup e Restore

Para restaurar um _dump_ do DB:

### Método 1 (mais indicado): _recovery_ completo (com arquivos de configuração)

Este método recupera arquivos que tenham sido gerados pelo serviço `backup` da _stack_ de _containers_, ou seja, arquivos do tipo `.tar.gz` com _backup_ dos arquivos de configuração do Matomo, além do _dump_ do DB.

**Atenção!** Para aplicar este método é necessário que seja utilizado o mesmo arquivo `.env` do _backup_, ou será necessário alterar a senha do MySQL no `config.inc.php`.

Caso tenha à sua disposição um arquivo `.tar.gz` gerado pelos [_scripts_ da plataforma](https://github.com/embrapa-io/backup), primeiro descompacte este arquivo e obtenha de dentro dele o `.env` original (com a senhas) e o arquivo `.tar.gz` gerado pelo serviço `backup` do Docker Compose.

Após criar os volumes e configurar o arquivo `.env`, suba apenas o _container_ do DB:

```bash
docker compose up --force-recreate --build --remove-orphans --wait db
```

Em seguida, faça a _build_ do serviço de `restore` e, na sequência, execute-o passando o arquivo de _backup_ (que já deve estar no volume `backup`):

```bash
docker compose build --force-rm --no-cache restore

BACKUP_FILE_TO_RESTORE=matomo_2025-02-05_12-47-47.tar.gz docker compose run --rm --no-deps restore
```

Agora suba todos os demais serviços:

```bash
docker compose up --force-recreate --build --remove-orphans --wait
```

### Método 2: utilizando o _script_ da imagem de _auto-backup_

Veja a seção de _restore_ na [documentação da imagem de _auto-backup_](https://github.com/fradelg/docker-mysql-cron-backup). Em resumo, copie o _dump_ para o diretório `backup` e faça:

```bash
docker compose exec auto-backup /restore.sh /backup/dump.sql.gz
```

### Método 3: pelo cliente do MariaDB

Acesse o _console_ do container do banco de dados:

```bash
docker compose exec db bash
```

Em seguida, faça:

```bash
cd /backup

gzip -d dump.sql.gz

mariadb --database matomo --user root --password < /backup/dump.sql
```

## Geolocalização

Após uma nova instalação (ou recuperação de _backup_) vá na [página de configuração na administração](https://matomo.embrapa.io/index.php?module=UserCountry&action=adminIndex) e configure a opção "**DBIP / GeoIP 2 (PHP)**". Trata-se basicamente de fazer download do BD de geolocalização no diretório `misc`.
