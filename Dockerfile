# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.1
FROM registry.docker.com/library/ruby:${RUBY_VERSION}-slim as base

WORKDIR /app

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development

FROM base as build

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential curl git node-gyp libyaml-dev pkg-config python-is-python3 libjemalloc2 && \
    rm -rf /var/lib/apt/lists/*

ARG NODE_VERSION=20.3.1
ARG YARN_VERSION=1.22.19
ENV PATH=/usr/local/node/bin:$PATH
ENV LD_PRELOAD="libjemalloc.so.2" \
    MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true" \
    RUBY_YJIT_ENABLE="1"
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    bundle exec bootsnap precompile app/ lib/

FROM base

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    curl libsqlite3-0 && \
    rm -rf /var/lib/apt/lists* /var/cache/apt/archives*

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

RUN useradd deploy --create-home --shell /bin/bash && \
    chown -R deploy:deploy db log storage tmp
USER deploy:deploy

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["./bin/rails", "server"]
