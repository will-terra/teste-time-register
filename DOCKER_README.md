

## How to Use

### 1. Prepare Environment
```bash
# Copy configurations
cp .env.example .env

# Start containers
docker compose up -d
```

### 2. Configure Database
```bash
docker compose exec app rails db:create db:migrate
```

### 3. Run Tests
```bash
docker compose exec app rspec
```

## Verification

- **Application**: http://localhost:3000
- **Health Check**: http://localhost:3000/up
- **Status**: `docker compose ps`

## Implementation

### Containers
- **app** - Rails Application (Ruby 3.4.6 + Multi-stage build)
- **db** - PostgreSQL 16  
- **redis** - Cache & Background Jobs
- **worker** - Solid Queue Worker

### Features
- **Isolated network** between containers
- **Persistent volumes** for data
- **Health checks** on all services
- **Environment variables** configurable via `.env`

### Docker Files
- `Dockerfile` - Optimized multi-stage build
- `docker-compose.yml` - Service orchestration
- `.dockerignore` - Build optimization  
- `.env.example` - Configuration template

## Extra Commands

```bash
# Stop containers
docker compose down

# View logs  
docker compose logs -f app

# Rails console
docker compose exec app rails console

# Container shell
docker compose exec app bash
```

