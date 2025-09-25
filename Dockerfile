# syntax=docker/dockerfile:1
# check=error=true

# Dockerfile multi-estágio otimizado para desenvolvimento e produção
# Build: docker build -t teste_time_register .
# Executar: docker run -d -p 3000:3000 --name teste_time_register teste_time_register

# Certifique-se de que RUBY_VERSION corresponde à versão Ruby em .ruby-version
ARG RUBY_VERSION=3.4.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# A aplicação Rails fica aqui
WORKDIR /rails

# Definir variáveis de ambiente
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Instalar pacotes base e limpar em uma única camada
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      postgresql-client \
      tzdata \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Configurar ambiente baseado em RAILS_ENV
ARG RAILS_ENV=production
ENV RAILS_ENV=$RAILS_ENV

# Definir configuração do bundle baseado no ambiente
RUN if [ "$RAILS_ENV" = "production" ]; then \
      bundle config set --local deployment 'true' && \
      bundle config set --local without 'development test'; \
    else \
      bundle config set --local without 'production'; \
    fi

# Estágio de build - estágio temporário para construir gems e compilar assets
FROM base AS build

# Instalar pacotes necessários para construir gems e ferramentas de desenvolvimento
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copiar arquivos de dependência primeiro para melhor cache
COPY Gemfile Gemfile.lock ./

# Instalar gems e limpar artefatos de build
RUN bundle install --jobs $BUNDLE_JOBS --retry $BUNDLE_RETRY && \
    rm -rf ~/.bundle/ \
           "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git \
           /tmp/* \
           /var/tmp/*

# Copiar código da aplicação
COPY . .

# Pré-compilar bootsnap para inicialização mais rápida
RUN bundle exec bootsnap precompile --gemfile && \
    bundle exec bootsnap precompile app/ lib/

# Criar diretórios e definir permissões
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log storage && \
    chmod -R 755 tmp log storage




# Estágio final de execução
FROM base AS runtime

# Copiar artefatos construídos: gems e aplicação
COPY --from=build --chown=1000:1000 "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=1000:1000 /rails /rails

# Criar usuário não-root para segurança
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Definir propriedade e permissões
RUN chown -R rails:rails /rails && \
    chmod +x /rails/bin/*

# Trocar para usuário não-root
USER rails:rails

# Adicionar verificação de saúde
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

# Entrypoint para preparar a aplicação
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Expor porta (3000 para desenvolvimento, pode ser sobrescrito)
EXPOSE 3000

# Comando padrão - pode ser sobrescrito no docker-compose
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]

# Estágio de produção com otimizações
FROM runtime AS production

# Voltar para root para instalar otimizações de produção
USER root

# Instalar pacotes específicos de produção
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      logrotate \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Voltar para usuário rails
USER rails:rails

# Sobrescrever comando padrão para produção com Thruster
CMD ["./bin/thrust", "./bin/rails", "server"]
EXPOSE 80
