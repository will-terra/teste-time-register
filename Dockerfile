# syntax=docker/dockerfile:1
# check=error=true

# Multi-stage Dockerfile optimized for both development and production
# Build: docker build -t teste_time_register .
# Run: docker run -d -p 3000:3000 --name teste_time_register teste_time_register

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Set environment variables
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Install base packages and clean up in one layer
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      postgresql-client \
      tzdata \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Configure environment based on RAILS_ENV
ARG RAILS_ENV=production
ENV RAILS_ENV=$RAILS_ENV

# Set bundle configuration based on environment
RUN if [ "$RAILS_ENV" = "production" ]; then \
      bundle config set --local deployment 'true' && \
      bundle config set --local without 'development test'; \
    else \
      bundle config set --local without 'production'; \
    fi

# Build stage - temporary stage to build gems and compile assets
FROM base AS build

# Install packages needed to build gems and development tools
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy dependency files first for better caching
COPY Gemfile Gemfile.lock ./

# Install gems and clean up build artifacts
RUN bundle install --jobs $BUNDLE_JOBS --retry $BUNDLE_RETRY && \
    rm -rf ~/.bundle/ \
           "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git \
           /tmp/* \
           /var/tmp/*

# Copy application code
COPY . .

# Precompile bootsnap for faster boot times
RUN bundle exec bootsnap precompile --gemfile && \
    bundle exec bootsnap precompile app/ lib/

# Create directories and set permissions
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log storage && \
    chmod -R 755 tmp log storage




# Final runtime stage
FROM base AS runtime

# Copy built artifacts: gems and application
COPY --from=build --chown=1000:1000 "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=1000:1000 /rails /rails

# Create non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Set ownership and permissions
RUN chown -R rails:rails /rails && \
    chmod +x /rails/bin/*

# Switch to non-root user
USER rails:rails

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

# Entrypoint to prepare the application
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Expose port (3000 for development, can be overridden)
EXPOSE 3000

# Default command - can be overridden in docker-compose
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]

# Production stage with optimizations
FROM runtime AS production

# Switch back to root to install production optimizations
USER root

# Install production-specific packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      logrotate \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Switch back to rails user
USER rails:rails

# Override default command for production with Thruster
CMD ["./bin/thrust", "./bin/rails", "server"]
EXPOSE 80
