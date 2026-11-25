FROM ruby:3.4

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .
