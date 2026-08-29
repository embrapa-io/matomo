FROM matomo:5.13.0

# Habilita mod_headers (CORS dos metadados) e mod_rewrite (repasse do Authorization)
RUN a2enmod headers rewrite

# Documentos de descoberta OAuth 2.0, servidos FORA do docroot (/var/www/html)
# para não serem mascarados pelo volume nomeado. O Apache os mapeia via Alias
# (ver well-known.conf). Copiados sem extensão para casar com os caminhos
# .well-known exigidos pelos clientes MCP.
COPY oauth-authorization-server.json /opt/well-known/oauth-authorization-server
COPY oauth-protected-resource.json   /opt/well-known/oauth-protected-resource

# Configuração do Apache que publica os metadados nos caminhos .well-known
COPY well-known.conf /etc/apache2/conf-enabled/zz-well-known.conf

# Repasse do cabeçalho Authorization ao PHP (necessário p/ tokens Bearer/OAuth)
COPY authorization.conf /etc/apache2/conf-enabled/zz-authorization.conf
