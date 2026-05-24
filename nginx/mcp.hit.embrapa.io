# Camada de usabilidade para o MCP Server do Matomo.
#
# Aplicado no **Nginx da VM** (NÃO é container / não entra no docker-compose).
# Expõe a URL limpa:
#
#     https://mcp.hit.embrapa.io
#         -> hit.embrapa.io/index.php?module=API&method=McpServer.mcp&format=mcp
#
# A autenticação OAuth permanece em hit.embrapa.io (authorization server). O
# recurso (mcp.hit.embrapa.io) apenas declara, via .well-known, que o seu AS é
# hit.embrapa.io — combinação válida pela RFC 9728.
#
# Pré-requisitos:
#   1. CNAME mcp.hit.embrapa.io -> hit.embrapa.io (ou o A record do servidor).
#   2. Certificado TLS: certbot --nginx -d mcp.hit.embrapa.io
#   3. Upstream = mesma porta do vhost hit.embrapa.io (container Matomo: 8081).

server {
    listen 80;
    listen [::]:80;
    server_name mcp.hit.embrapa.io;
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mcp.hit.embrapa.io;

    ssl_certificate     /etc/letsencrypt/live/mcp.hit.embrapa.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mcp.hit.embrapa.io/privkey.pem;

    # Metadado de descoberta: aponta o recurso para o AS em hit.embrapa.io.
    # (NÃO servir oauth-authorization-server aqui: o issuer é hit.embrapa.io e
    #  alguns clientes validam issuer == origem do fetch, causando mismatch.)
    location = /.well-known/oauth-protected-resource {
        default_type application/json;
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
        return 200 '{"resource":"https://mcp.hit.embrapa.io","authorization_servers":["https://hit.embrapa.io"]}';
    }

    # Endpoint MCP: qualquer caminho é reescrito para a query fixa do McpServer.
    location / {
        rewrite ^ /index.php?module=API&method=McpServer.mcp&format=mcp break;
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host hit.embrapa.io;               # host confiável p/ o Matomo
        proxy_set_header Authorization $http_authorization;  # repassa o Bearer
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
