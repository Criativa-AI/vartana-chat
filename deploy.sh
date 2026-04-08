#!/bin/bash

# Vartana Talk Deployment Script
# This script pulls the latest changes and rebuilds the containers without cache
# to ensure all branding and code changes are applied.

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
