FROM matomo:5

# Habilita mod_headers (necessário para os cabeçalhos CORS dos metadados OAuth)
RUN a2enmod headers

# Documentos de descoberta OAuth 2.0, servidos FORA do docroot (/var/www/html)
# para não serem mascarados pelo volume nomeado. O Apache os mapeia via Alias
# (ver well-known.conf). Copiados sem extensão para casar com os caminhos
# .well-known exigidos pelos clientes MCP.
COPY oauth-authorization-server.json /opt/well-known/oauth-authorization-server
COPY oauth-protected-resource.json   /opt/well-known/oauth-protected-resource

# Configuração do Apache que publica os metadados nos caminhos .well-known
COPY well-known.conf /etc/apache2/conf-enabled/zz-well-known.conf
