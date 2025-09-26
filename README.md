# TIME-REGISTER

**Time-register** — Sistema de relógio de ponto (API-only) implementado em Ruby on Rails. Projeto de exemplo para demonstrar APIs RESTful, processamento assíncrono de relatórios, geração de CSV, população de dados e containerização com Docker. O foco deste repositório é fornecer uma API bem testada e pronta para demonstração técnica.

---

## 1. Título e Descrição
**time-register**

API-only Rails app para controle de ponto (clock in / clock out). Permite CRUD de usuários e registros de ponto, geração de relatórios por período em background e download dos relatórios em CSV.

---

## 2. Pré-requisitos
- Ruby 2.6+ / 3.x (Rails 6.0+ compatível)
- Bundler
- PostgreSQL (versão compatível com sua instalação de Rails)
- Docker & docker-compose (para execução em containers)
- Redis (recomendado se optar por Sidekiq como adapter de Active Job)
- RSpec (incluído no Gemfile) e SimpleCov para cobertura

---

## 3. Instalação e Setup
### Clone do repositório
```bash
git clone https://github.com/will-terra/teste-time-register.git
cd time-register
```

### Instalação de dependências
```bash
bundle install
```

### Configuração de variáveis de ambiente
Crie um arquivo `.env` ou configure variáveis no ambiente:
- `DATABASE_URL` (opcional — usado em produção/container)
- `RAILS_ENV` (development/test/production)
- `SECRET_KEY_BASE`
- `REDIS_URL` (se usar Sidekiq)

Um `.env.example` com as chaves mínimas é fornecido no repositório.

### Setup do banco de dados (local)
```bash
rails db:create db:migrate
# opcional: popular dados de demonstração
rails db:seed
# ou tarefa específica
rails runner db/seeds/populate_time_registers.rb
```

---

## 4. Como Executar
### Desenvolvimento local
```bash
# iniciar servidor Rails
bundle exec rails server -p 3000
```

### Via Docker (desenvolvimento)
```bash
# levantar containers
docker-compose up -d
# criar e migrar banco (conforme requisito do desafio)
docker-compose exec app rails db:create db:migrate
# executar testes dentro do container
docker-compose exec app rspec
```

### Execução de testes
Localmente:
```bash
bundle exec rspec
```
Com cobertura (SimpleCov): ao rodar `rspec` será gerado `coverage/index.html`.

---

## 5. Documentação da API
Base path: `/api/v1`

### Users
- `GET /api/v1/users`
  - Lista todos os usuários
  - **200 OK** — JSON array de usuários

- `GET /api/v1/users/:id`
  - Retorna um usuário específico
  - **200 OK** — usuário JSON
  - **404 Not Found** — usuário não encontrado

- `POST /api/v1/users`
  - Cria um novo usuário
  - Body (JSON): `{ "name": "Nome", "email": "email@exemplo.com" }`
  - **201 Created** — usuário criado
  - **422 Unprocessable Entity** — validações (ex.: email inválido, email já existe)

- `PUT /api/v1/users/:id`
  - Atualiza um usuário
  - Body (JSON): `{ "name": "Novo Nome", "email": "novo@ex.com" }`
  - **200 OK** — usuário atualizado
  - **422 / 404** — erros

- `DELETE /api/v1/users/:id`
  - Remove um usuário
  - **204 No Content** — sucesso
  - **404 Not Found** — usuário não encontrado

- `GET /api/v1/users/:id/time_registers`
  - Lista registros de ponto do usuário
  - **200 OK** — array de registros

---

### Time Registers
- `GET /api/v1/time_registers`
  - Lista todos os registros de ponto
  - **200 OK**

- `GET /api/v1/time_registers/:id`
  - Retorna um registro específico
  - **200 OK** / **404 Not Found**

- `POST /api/v1/time_registers`
  - Cria um novo registro de ponto
  - Body (JSON): `{ "user_id": 1, "clock_in": "2025-09-01T09:00:00Z", "clock_out": null }`
  - Regras de validação:
    - Um usuário não pode ter mais de um registro "aberto" (sem `clock_out`).
    - `clock_out`, quando informado, deve ser posterior a `clock_in`.
  - **201 Created** — criado
  - **422 Unprocessable Entity** — violação das validações

- `PUT /api/v1/time_registers/:id`
  - Atualiza um registro (por exemplo para fechar o ponto adicionando `clock_out`)
  - Body (JSON): `{ "clock_out": "2025-09-01T17:00:00Z" }`
  - **200 OK** / **422** / **404**

- `DELETE /api/v1/time_registers/:id`
  - Remove um registro
  - **204 No Content** / **404 Not Found**

---

### Relatórios (Processamento Assíncrono)
- `POST /api/v1/users/:id/reports`
  - Solicita geração de relatório do usuário no intervalo `start_date` e `end_date`.
  - Body (JSON): `{ "start_date": "2025-08-01", "end_date": "2025-08-31" }`
  - Resposta: **202 Accepted** (ou 201) com JSON: `{ "process_id": "<uuid>", "status": "queued" }`
  - O endpoint enfileira um job que processará os registros e gerará um CSV.

- `GET /api/v1/reports/:process_id/status`
  - Consulta o status do processo
  - Resposta: **200 OK** — `{ "process_id": "<uuid>", "status": "processing|completed|failed", "progress": 75 }`

- `GET /api/v1/reports/:process_id/download`
  - Download do relatório
  - Se pronto: retorna arquivo CSV (`Content-Type: text/csv`) ou **302 Redirect** para URL temporária (S3 presigned URL)
  - Se não pronto: **404 Not Found** ou **409 Conflict** com mensagem indicando `processing`

---

### Códigos HTTP usados (visão geral)
- `200 OK` — requisição bem sucedida
- `201 Created` / `202 Accepted` — recurso criado / processamento enfileirado
- `204 No Content` — exclusão bem sucedida
- `400 Bad Request` — parâmetros inválidos
- `401 Unauthorized` — (se aplicar autenticação)
- `404 Not Found` — recurso não encontrado
- `409 Conflict` — tentativa de ação inválida (ex.: abrir 2 registros abertos)
- `422 Unprocessable Entity` — validações falharam
- `500 Internal Server Error` — erro no servidor

---

## 6. Arquitetura do Projeto
Estrutura de pastas (resumo):

```
app/
  controllers/
    api/
      v1/
        users_controller.rb
        time_registers_controller.rb
        reports_controller.rb
  models/
    user.rb
    time_register.rb
    report_process.rb  # (opcional) armazena process_id, status, file_path
  jobs/
    generate_report_job.rb
  services/
    report_generator_service.rb
  serializers/ (opcional)
config/
spec/
```

Padrões e decisões técnicas:
- **API-only**: respostas JSON e controllers sob `Api::V1`.
- **Background processing**: Active Job (adapter configurável). Recomenda-se `Sidekiq` + `Redis` para produção por robustez; em dev pode ser `async` ou `inline` para testes.
- **Geração de CSV**: `CSV` da stdlib; escrita em arquivo temporário (`tmp/reports/<uuid>.csv`) ou upload para armazenamento externo (S3) em produção.
- **Persistência do estado do relatório**: modelo `ReportProcess` para guardar `process_id (uuid)`, `status`, `progress` e `file_path`.
- **Validações no modelo**: garantir unicidade do registro aberto por usuário, e checar `clock_out > clock_in`.

---

## 7. Testes
- Suite de testes com **RSpec** cobrindo:
  - Model specs: validações e associações
  - Request specs: todos os endpoints da API
  - Job/Service specs: geração de relatórios em background
  - Integration specs: fluxos completos (ex.: abrir ponto → fechar ponto → gerar relatório → download)
- Cobertura mínima: **90%**. O projeto integra `SimpleCov` para geração de relatório de cobertura.

Como executar:
```bash
bundle exec rspec
# dentro do container
docker-compose exec app rspec
```

Os relatórios de cobertura ficam em `coverage/index.html`.

---

## 8. Deploy (instruções básicas)
- Build da imagem Docker (exemplo):
```bash
docker build -t time-register:latest .
```
- Em ambiente de produção, configurar variáveis: `DATABASE_URL`, `RAILS_ENV=production`, `SECRET_KEY_BASE`, `REDIS_URL` (se aplicável).
- Migrar banco e iniciar processos de background (Sidekiq ou outro):
```bash
# ex: executar migrações
docker-compose run --rm app rails db:migrate
# iniciar web e worker
docker-compose up -d
```
- Para armazenamento de arquivos em produção, recomenda-se usar S3 ou armazenamento de objetos com expiração de arquivos (presigned URLs para download seguro).

---


