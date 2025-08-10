ARG BUILDER_IMAGE="elixir:1.18"
ARG RUNNER_IMAGE="elixir:1.18"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git sed ca-certificates curl libssl-dev wget libxslt-dev pkg-config libxml2 libxml2-dev libgeos-dev \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# install NVM
ENV NVM_DIR="/usr/local/nvm"
ENV NODE_VERSION="v22.18.0"

# Install nvm with node and npm
RUN mkdir -p $NVM_DIR \
    && curl https://raw.githubusercontent.com/creationix/nvm/v0.39.1/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Install Rust and Cargo
RUN curl https://sh.rustup.rs -sSf > rust_install.sh && \
     chmod +x rust_install.sh && \
    ./rust_install.sh -y

ENV NODE_PATH="$NVM_DIR/v$NODE_VERSION/lib/node_modules"
ENV PATH="$NVM_DIR/v$NODE_VERSION/bin:/root/.cargo/bin:$PATH"

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./

RUN mix deps.get --only $MIX_ENV
RUN mkdir config

ENV RUSTFLAGS="--codegen target-feature=-crt-static"

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

# Compile the release
COPY lib lib

COPY assets assets

RUN . $NVM_DIR/nvm.sh && npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

# compile assets
RUN . $NVM_DIR/nvm.sh && mix assets.deploy

RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ffmpeg curl libxml2 libxml2-dev libgeos-dev \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

RUN groupadd -r steve -g 7000 && useradd -u 7000 -r -g steve -s /sbin/nologin -c "ExSRF steve user" steve

WORKDIR "/app"

RUN chown steve -R /app

# Only copy the final release from the build stage
COPY --from=builder --chown=steve:root /app/_build/prod/rel/basenji ./

USER steve

ARG GIT_HASH

ENV GIT_HASH="$GIT_HASH"


ENTRYPOINT ["/app/bin/server"]
