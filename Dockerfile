FROM ruby:2.3.7-alpine

RUN apk add --update git \
  build-base \
  nodejs \
  tzdata \
  && rm -rf /var/cache/apk/*

WORKDIR /app

COPY .ruby-version Gemfile* ./
RUN gem install bundler
RUN bundle install
