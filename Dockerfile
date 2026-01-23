FROM ruby:3.3.0-slim AS builder

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_WITHOUT=development:test \
    GRPC_RUBY_GEM_USE_SYSTEM_LIBRARIES=1 \
    PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
      build-essential \
      libsqlite3-dev \
      libssl-dev \
      pkg-config \
      protobuf-compiler \
      libprotobuf-dev \
      libgrpc-dev \
      git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem update --system \
    && gem install bundler \
    && bundle install

FROM ruby:3.3.0-slim

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_WITHOUT=development:test \
    GRPC_RUBY_GEM_USE_SYSTEM_LIBRARIES=1 \
    PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
      libsqlite3-dev \
      libssl-dev \
      pkg-config \
      libprotobuf-dev \
      libgrpc-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .
RUN mkdir -p db

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "4567"]
