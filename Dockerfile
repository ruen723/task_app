ARG RUBY_VERSION=3.4.13
FROM ruby:${RUBY_VERSION}-slim-trixie AS base

ARG BUNDLER_VERSION=2.6.9
WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libmariadb3 && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundler --version "${BUNDLER_VERSION}" --no-document

FROM base AS development

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

FROM base AS build

ENV RAILS_ENV=production \
    BUNDLE_FROZEN=1 \
    BUNDLE_WITHOUT=development:test

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential default-libmysqlclient-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf "${GEM_HOME}/cache"

COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && \
    rm -f tmp/local_secret.txt

FROM base AS production

ENV RAILS_ENV=production \
    BUNDLE_FROZEN=1 \
    BUNDLE_WITHOUT=development:test \
    WEB_CONCURRENCY=0

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN groupadd --system rails && \
    useradd --system --gid rails --create-home rails && \
    mkdir -p log tmp storage && \
    chown -R rails:rails log tmp storage

USER rails
CMD ["sh", "-c", ": \"${DATABASE_URL:?DATABASE_URL is required}\" \"${SECRET_KEY_BASE:?SECRET_KEY_BASE is required}\"; exec bundle exec puma -C config/puma.rb"]
