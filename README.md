# TIME-REGISTER

**Time-register** — Time clock system (API-only) implemented in Ruby on Rails. Example project to demonstrate RESTful APIs, asynchronous report processing, CSV generation, data population, and Docker containerization. The focus of this repository is to provide a well-tested API ready for technical demonstration.

---

## 1. Title and Description
**time-register**

API-only Rails app for time tracking (clock in / clock out). Allows CRUD operations for users and time records, background report generation by period, and CSV report downloads.

---

## 2. Prerequisites
- Ruby 2.6+ / 3.x (Rails 6.0+ compatible)
- Bundler
- PostgreSQL (version compatible with your Rails installation)
- Docker & docker-compose (for container execution)
- Redis (recommended if using Sidekiq as Active Job adapter)
- RSpec (included in Gemfile) and SimpleCov for coverage

---

## 3. Installation and Setup
### Repository clone
```bash
git clone <repo-url> time-register
cd time-register
```

### Dependency installation
```bash
bundle install
```

### Environment variables configuration
Create a `.env` file or configure environment variables:
- `DATABASE_URL` (optional — used in production/container)
- `RAILS_ENV` (development/test/production)
- `SECRET_KEY_BASE`
- `REDIS_URL` (if using Sidekiq)

A `.env.example` with minimal keys is provided in the repository.

### Database setup (local)
```bash
rails db:create db:migrate
# optional: populate demo data
rails db:seed
# or specific task
rails runner db/seeds/populate_time_registers.rb
```

---

## 4. How to Run
### Local development
```bash
# start Rails server
bundle exec rails server -p 3000
```

### Via Docker (development)
```bash
# start containers
docker-compose up -d
# create and migrate database (as per challenge requirement)
docker-compose exec app rails db:create db:migrate
# run tests inside container
docker-compose exec app rspec
```

### Test execution
Locally:
```bash
bundle exec rspec
```
With coverage (SimpleCov): running `rspec` will generate `coverage/index.html`.

---

## 5. API Documentation
Base path: `/api/v1`

### Users
- `GET /api/v1/users`
  - Lists all users
  - **200 OK** — JSON array of users

- `GET /api/v1/users/:id`
  - Returns a specific user
  - **200 OK** — user JSON
  - **404 Not Found** — user not found

- `POST /api/v1/users`
  - Creates a new user
  - Body (JSON): `{ "name": "Name", "email": "email@example.com" }`
  - **201 Created** — user created
  - **422 Unprocessable Entity** — validations (e.g.: invalid email, email already exists)

- `PUT /api/v1/users/:id`
  - Updates a user
  - Body (JSON): `{ "name": "New Name", "email": "new@ex.com" }`
  - **200 OK** — user updated
  - **422 / 404** — errors

- `DELETE /api/v1/users/:id`
  - Removes a user
  - **204 No Content** — success
  - **404 Not Found** — user not found

- `GET /api/v1/users/:id/time_registers`
  - Lists user's time records
  - **200 OK** — array of records

---

### Time Registers
- `GET /api/v1/time_registers`
  - Lists all time records
  - **200 OK**

- `GET /api/v1/time_registers/:id`
  - Returns a specific record
  - **200 OK** / **404 Not Found**

- `POST /api/v1/time_registers`
  - Creates a new time record
  - Body (JSON): `{ "user_id": 1, "clock_in": "2025-09-01T09:00:00Z", "clock_out": null }`
  - Validation rules:
    - A user cannot have more than one "open" record (without `clock_out`).
    - `clock_out`, when provided, must be after `clock_in`.
  - **201 Created** — created
  - **422 Unprocessable Entity** — validation violations

- `PUT /api/v1/time_registers/:id`
  - Updates a record (e.g., to close time by adding `clock_out`)
  - Body (JSON): `{ "clock_out": "2025-09-01T17:00:00Z" }`
  - **200 OK** / **422** / **404**

- `DELETE /api/v1/time_registers/:id`
  - Removes a record
  - **204 No Content** / **404 Not Found**

---

### Reports (Asynchronous Processing)
- `POST /api/v1/users/:id/reports`
  - Requests user report generation for `start_date` and `end_date` interval.
  - Body (JSON): `{ "start_date": "2025-08-01", "end_date": "2025-08-31" }`
  - Response: **202 Accepted** (or 201) with JSON: `{ "process_id": "<uuid>", "status": "queued" }`
  - The endpoint queues a job that will process records and generate a CSV.

- `GET /api/v1/reports/:process_id/status`
  - Queries process status
  - Response: **200 OK** — `{ "process_id": "<uuid>", "status": "processing|completed|failed", "progress": 75 }`

- `GET /api/v1/reports/:process_id/download`
  - Report download
  - If ready: returns CSV file (`Content-Type: text/csv`) or **302 Redirect** to temporary URL (S3 presigned URL)
  - If not ready: **404 Not Found** or **409 Conflict** with message indicating `processing`

---

### HTTP Codes used (overview)
- `200 OK` — successful request
- `201 Created` / `202 Accepted` — resource created / processing queued
- `204 No Content` — successful deletion
- `400 Bad Request` — invalid parameters
- `401 Unauthorized` — (if authentication applies)
- `404 Not Found` — resource not found
- `409 Conflict` — invalid action attempt (e.g.: opening 2 open records)
- `422 Unprocessable Entity` — validations failed
- `500 Internal Server Error` — server error

---

## 6. Project Architecture
Folder structure (summary):

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
    report_process.rb  # (optional) stores process_id, status, file_path
  jobs/
    generate_report_job.rb
  services/
    report_generator_service.rb
  serializers/ (optional)
config/
spec/
```

Patterns and technical decisions:
- **API-only**: JSON responses and controllers under `Api::V1`.
- **Background processing**: Active Job (configurable adapter). `Sidekiq` + `Redis` recommended for production due to robustness; in dev can be `async` or `inline` for tests.
- **CSV generation**: `CSV` from stdlib; writing to temporary file (`tmp/reports/<uuid>.csv`) or upload to external storage (S3) in production.
- **Report state persistence**: `ReportProcess` model to store `process_id (uuid)`, `status`, `progress` and `file_path`.
- **Model validations**: ensure uniqueness of open record per user, and check `clock_out > clock_in`.

---

## 7. Tests
- Test suite with **RSpec** covering:
  - Model specs: validations and associations
  - Request specs: all API endpoints
  - Job/Service specs: background report generation
  - Integration specs: complete flows (e.g.: clock in → clock out → generate report → download)
- Minimum coverage: **90%**. The project integrates `SimpleCov` for coverage report generation.

How to run:
```bash
bundle exec rspec
# inside container
docker-compose exec app rspec
```

Coverage reports are in `coverage/index.html`.

---

## 8. Deploy (basic instructions)
- Docker image build (example):
```bash
docker build -t time-register:latest .
```
- In production environment, configure variables: `DATABASE_URL`, `RAILS_ENV=production`, `SECRET_KEY_BASE`, `REDIS_URL` (if applicable).
- Migrate database and start background processes (Sidekiq or other):
```bash
# e.g.: run migrations
docker-compose run --rm app rails db:migrate
# start web and worker
docker-compose up -d
```
- For file storage in production, it's recommended to use S3 or object storage with file expiration (presigned URLs for secure download).

---