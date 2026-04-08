#!/bin/bash

# Vartana Talk Deployment Script
# 
# Para executar este script LOCALMENTE na VPS, use:
# ./deploy.sh
# 
# Para executar REMOTAMENTE da sua máquina (via SSH), use:
# ssh -i ~/.ssh/hetzner_key root@135.181.101.28 "cd ~/projetos/vartana-chat && ./deploy.sh"
# 
# Este script puxa as últimas alterações e reconstrói os containers sem cache
# para garantir que todas as mudanças de marca e código sejam aplicadas.

echo "🚀 Iniciando deploy do Vartana Talk..."

# 1. Puxar as últimas alterações do Git
echo "📥 Puxando alterações do Git..."
git pull

# 2. Resetar o arquivo docker-compose se houver mudanças locais (caso necessário)
# git checkout docker-compose.production.yaml

# 3. Buildar os containers sem cache para o rails e sidekiq
echo "🏗️  Reconstruindo containers (isso pode levar alguns minutos)..."
docker compose -f docker-compose.production.yaml build --no-cache rails sidekiq

# 4. Subir os containers atualizados
echo "🆙 Subindo os serviços..."
docker compose -f docker-compose.production.yaml up -d

echo "✅ Deploy finalizado com sucesso!"
