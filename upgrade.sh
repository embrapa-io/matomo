#!/bin/bash
# ============================================
# Upgrade Script - Matomo (Embrapa I/O)
# ============================================
# Atualiza o Matomo (hit.embrapa.io) via CLI — recomendado para esta instância
# (~1000 sites): a migração de banco pela UI pode estourar timeout e deixar o
# schema meio migrado.
#
# O que o script faz:
#   1. Confere a versão atual (console core:version) e valida que a nova é maior;
#   2. Baixa a imagem oficial matomo:<versão> (aborta se a tag não existir);
#   3. Pina a versão no docker/matomo/Dockerfile e recria o container;
#   4. Copia os arquivos novos da imagem para o volume (o entrypoint oficial
#      só popula volume VAZIO — nunca atualiza), ajusta permissões e roda a
#      migração do banco (console core:update).
#
# PRÉ-REQUISITO: backup + archive já executados (é o que faz o
# /var/opt/embrapa.io/scripts/matomo.sh do repositório embrapa-io/backup).
#
# Uso: ./upgrade.sh <versão>   (ex.: ./upgrade.sh 5.13.0)
#
# Ao final, commite e envie a mudança do Dockerfile (o script imprime o comando).
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="$1"

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Uso: $0 <versão do Matomo> (ex.: $0 5.13.0)"
    echo "Versão pinada no Dockerfile: $(grep -oE 'matomo:[0-9.]+|matomo:[0-9]+' docker/matomo/Dockerfile | head -1)"
    exit 1
fi

command -v docker >/dev/null 2>&1 || { echo -e "❌ ${RED}Docker não encontrado!${NC}"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo -e "❌ ${RED}Docker Compose V2 não encontrado!${NC}"; exit 1; }
[ -f ".env" ] || { echo -e "❌ ${RED}Arquivo .env não encontrado!${NC}"; exit 1; }

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Upgrade do Matomo → v${VERSION}${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Aviso se o backup mais recente for velho (o script NÃO faz backup)
BKP_PATH="/var/opt/embrapa.io/backup"
if [ -d "$BKP_PATH" ]; then
    LAST_BKP=$(ls -t "$BKP_PATH"/io_matomo_*.tar.gz 2>/dev/null | head -1)
    if [ -z "$LAST_BKP" ] || [ -n "$(find "$LAST_BKP" -mmin +1440 2>/dev/null)" ]; then
        echo -e "⚠️  ${YELLOW}Nenhum backup das últimas 24h em ${BKP_PATH}!${NC}"
        echo -e "   Último encontrado: ${LAST_BKP:-nenhum}"
        read -r -p "   Continuar mesmo assim? (digite 'sim') " CONFIRM
        [ "$CONFIRM" = "sim" ] || { echo "Abortado."; exit 1; }
    else
        echo -e "ℹ️  Backup recente encontrado: $(basename "$LAST_BKP")"
    fi
fi

echo -e "ℹ️  Verificando a versão atual..."
CURRENT=$(docker compose exec -T matomo php /var/www/html/console core:version 2>/dev/null | tr -cd '0-9.')
[ -n "$CURRENT" ] || { echo -e "❌ ${RED}Não foi possível ler a versão atual (stack no ar?).${NC}"; exit 1; }
echo -e "   Atual: v${CURRENT} → Alvo: v${VERSION}"

if [ "$CURRENT" = "$VERSION" ]; then
    echo -e "✅ ${GREEN}Já está na v${VERSION}. Nada a fazer.${NC}"
    exit 0
fi
NEWEST=$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)
if [ "$NEWEST" != "$VERSION" ]; then
    echo -e "❌ ${RED}A versão alvo (v${VERSION}) é MENOR que a atual (v${CURRENT}) — downgrade não suportado.${NC}"
    exit 1
fi

echo -e "ℹ️  Baixando a imagem matomo:${VERSION}..."
docker pull "matomo:${VERSION}" || { echo -e "❌ ${RED}Tag matomo:${VERSION} não existe no Docker Hub.${NC}"; exit 1; }

echo -e "ℹ️  Pinando a versão no Dockerfile e recriando o container..."
sed -i "s|^FROM matomo:.*|FROM matomo:${VERSION}|" docker/matomo/Dockerfile
grep "^FROM" docker/matomo/Dockerfile
docker compose build matomo
docker compose up -d --force-recreate --wait matomo

echo -e "ℹ️  Copiando os arquivos v${VERSION} da imagem para o volume..."
docker compose exec -T matomo sh -c 'tar cf - --one-file-system -C /usr/src/matomo . | tar xf - -C /var/www/html'

echo -e "ℹ️  Ajustando permissões..."
docker compose exec -T matomo chown -R www-data:www-data /var/www/html

echo -e "ℹ️  Executando a migração do banco (pode demorar — NÃO interrompa)..."
docker compose exec -T -u www-data matomo php /var/www/html/console core:update --yes

FINAL=$(docker compose exec -T matomo php /var/www/html/console core:version | tr -cd '0-9.')
echo ""
if [ "$FINAL" = "$VERSION" ]; then
    echo -e "🚀 ${GREEN}Matomo atualizado para v${FINAL}.${NC}"
else
    echo -e "⚠️  ${YELLOW}Versão final lida: v${FINAL} (esperado v${VERSION}) — verifique!${NC}"
fi
echo ""
echo -e "⚠️  Confira o diagnóstico de integridade (Administração → Diagnóstico): a cópia por tar"
echo -e "   NÃO remove arquivos que a versão nova aboliu — o Matomo lista as sobras e fornece o"
echo -e "   comando rm; execute-o dentro do container: docker compose exec -T matomo rm \"...\""
echo ""
echo -e "⚠️  Valide na UI (https://hit.embrapa.io) e registre a versão no repositório — copie e cole:"
echo ""
echo "git add docker/matomo/Dockerfile && git commit -m \"Atualização do Matomo para a v${VERSION}.\" && git push origin main"
