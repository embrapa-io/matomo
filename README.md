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

⚠️ **Sempre pela CLI** — nesta instância (~1000 sites) a migração de banco pela UI pode estourar timeout e deixar o schema meio migrado. Detalhe importante da imagem oficial: o entrypoint **só popula o volume vazio** (primeira instalação) — ele nunca atualiza os arquivos, por isso a cópia manual faz parte do fluxo.

1. Execute o backup + archive: é o `matomo.sh` dos [_scripts_ da plataforma](https://github.com/embrapa-io/backup).
2. Rode o script de upgrade com a versão alvo:

```bash
./upgrade.sh 5.13.0
```

O script valida a versão (atual < alvo), baixa a imagem oficial, pina a versão no `docker/matomo/Dockerfile`, recria o container, copia os arquivos novos para o volume, ajusta permissões e roda a migração do banco (`console core:update`). Ao final, imprime o comando de commit+push para registrar a versão no repositório.

3. Valide na UI (versão, tracking, próximo ciclo do archive). O script já remove os arquivos que a versão nova aboliu, pela lista do próprio diagnóstico de integridade do Matomo (`console diagnostics:run`), nunca em `config/`, `tmp/` ou `misc/user/`; confira em Administração → Diagnóstico se não sobrou aviso.

> **Plugins** (marketplace) podem ser atualizados **pela UI** normalmente — são pequenos e sem migração pesada. Após atualizar `OAuth2`/`McpServer`, testar o cliente MCP (os metadados `.well-known` customizados dependem deles).

## Logs (Loki)

Os containers enviam logs ao Loki da plataforma via **plugin Docker** (`log-driver: loki` no `/etc/docker/daemon.json` do host — o compose **não** define `logging:` justamente para herdar esse default). Requisitos no host:

```bash
docker plugin install grafana/loki-docker-driver:3.5.5 --alias loki --grant-all-permissions
```

No `daemon.json`, usar o padrão da plataforma com `loki-external-labels: host=hit.embrapa.io,job=docker` (o hostname da VM é curto — sem o label explícito, os logs chegariam com identidade divergente do Alloy) e `systemctl restart docker`. ⚠️ Aplicar o `daemon.json` **antes** de recriar os containers — sem o default do daemon, containers recriados cairiam em `json-file` sem rotação.

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
