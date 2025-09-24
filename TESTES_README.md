# Suíte de Testes Completa - Time Register API

## 🧪 Tipos de Testes Implementados

### ✅ Model Specs (Validações e Associações)
- **User Model**: 13 testes
  - Validações de presença (name, email)
  - Validação de unicidade e formato de email
  - Associação `has_many :time_registers`
  - Método `has_open_time_register?`
  - Dependent destroy de time_registers

- **TimeRegister Model**: 18 testes
  - Validação de presença (clock_in)
  - Associação `belongs_to :user`
  - Validação customizada: usuário não pode ter múltiplos registros abertos
  - Validação customizada: clock_out deve ser após clock_in
  - Cenários complexos de negócio

### ✅ Request Specs (Endpoints da API)
- **Users API**: 23 testes
  - GET `/api/v1/users` - Lista usuários
  - GET `/api/v1/users/:id` - Busca usuário específico
  - POST `/api/v1/users` - Cria novo usuário
  - PUT `/api/v1/users/:id` - Atualiza usuário
  - DELETE `/api/v1/users/:id` - Remove usuário
  - GET `/api/v1/users/:id/time_registers` - Registros do usuário

- **Time Registers API**: 29 testes
  - GET `/api/v1/time_registers` - Lista todos os registros
  - GET `/api/v1/time_registers/:id` - Busca registro específico
  - POST `/api/v1/time_registers` - Cria novo registro
  - PUT `/api/v1/time_registers/:id` - Atualiza registro
  - DELETE `/api/v1/time_registers/:id` - Remove registro
  - Casos extremos e lógica de negócio

### ✅ Integration Specs (Fluxos Completos)
- **Fluxo Completo de Rastreamento**: 4 testes
  - Registro de usuário → Clock in → Clock out → Múltiplas entradas
  - Gerenciamento de múltiplos usuários simultâneos
  - Tratamento de erros e casos extremos
  - Consistência de dados em operações complexas

## 🏗️ Configuração de Testes

### Gems Adicionadas
```ruby
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end

group :test do
  gem "simplecov", require: false
  gem "simplecov-html", require: false
end
```

### Configurações
- **RSpec**: Configurado com helper completo
- **SimpleCov**: Cobertura mínima de 90%, filtros apropriados
- **FactoryBot**: Factories para User e TimeRegister
- **DatabaseCleaner**: Estratégia de transação para performance
- **Shoulda Matchers**: Testes de validação e associação

## 📁 Estrutura de Testes

```
spec/
├── rails_helper.rb          # Configuração principal
├── spec_helper.rb          # Configuração do RSpec
├── support/
│   └── shoulda_matchers.rb # Configuração Shoulda
├── factories/
│   ├── users.rb           # Factory para usuários
│   └── time_registers.rb  # Factory para registros
├── models/
│   ├── user_spec.rb       # Testes do modelo User
│   └── time_register_spec.rb # Testes do modelo TimeRegister
├── requests/
│   └── api/v1/
│       ├── users_spec.rb  # Testes API de usuários
│       └── time_registers_spec.rb # Testes API de registros
└── integration/
    └── time_tracking_flow_spec.rb # Testes de integração
```


## 🚀 Como Executar os Testes

```bash
# Instalar dependências
bundle install

# Configurar banco de teste
rails db:create db:migrate RAILS_ENV=test

# Executar todos os testes
bundle exec rspec

# Executar com formato detalhado
bundle exec rspec --format documentation

# Executar testes específicos
bundle exec rspec spec/models/
bundle exec rspec spec/requests/
bundle exec rspec spec/integration/
```

## 📈 Relatório de Cobertura

O relatório HTML detalhado está disponível em `coverage/index.html` após executar os testes.

## ✨ Recursos Utilizados

- **RSpec Rails**: Framework de testes principal
- **FactoryBot**: Geração de dados de teste
- **Faker**: Dados realísticos aleatórios
- **Shoulda Matchers**: Testes de validação simplificados
- **SimpleCov**: Análise de cobertura de código
- **DatabaseCleaner**: Limpeza de dados entre testes
