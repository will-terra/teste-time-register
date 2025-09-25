

## 🚀 Como Usar

### 1. Preparar Ambiente
```bash
# Copiar configurações
cp .env.example .env

# Iniciar containers
docker compose up -d
```

### 2. Configurar Base de Dados  
```bash
docker compose exec app rails db:create db:migrate
```

### 3. Executar Testes
```bash
docker compose exec app rspec
```

## ✅ Verificação

- **Aplicação**: http://localhost:3000
- **Health Check**: http://localhost:3000/up
- **Status**: `docker compose ps`

## 🏗️ Implementação

### Containers
- **app** - Rails Application (Ruby 3.4.6 + Multi-stage build)
- **db** - PostgreSQL 16  
- **redis** - Cache & Background Jobs
- **worker** - Solid Queue Worker

### Características  
- **Network isolada** entre containers
- **Volumes persistentes** para dados
- **Health checks** em todos os serviços
- **Variáveis de ambiente** configuráveis via `.env`

### Arquivos Docker
- `Dockerfile` - Multi-stage build otimizado
- `docker-compose.yml` - Orquestração dos serviços
- `.dockerignore` - Otimização do build  
- `.env.example` - Template de configuração

## 🛠️ Comandos Extras

```bash
# Parar containers
docker compose down

# Ver logs  
docker compose logs -f app

# Console Rails
docker compose exec app rails console

# Shell do container
docker compose exec app bash
```

