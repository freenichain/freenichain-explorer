# SPDX-License-Identifier: Apache-2.0
# Modernized for Node 24 + linux/arm64
# Changes from upstream:
#   - node:13-alpine → node:24-alpine3.23
#   - Removed node-prune (amd64-only binary) → find-based pruning
#   - Added --legacy-peer-deps for React 16 client deps
#   - NODE_OPTIONS=--openssl-legacy-provider for react-scripts on Node 17+

FROM node:24-alpine3.23 AS build

ENV DEFAULT_WORKDIR=/opt
ENV EXPLORER_APP_PATH=$DEFAULT_WORKDIR/explorer

WORKDIR $EXPLORER_APP_PATH

COPY . .

RUN apk add --no-cache --virtual npm-deps python3 make g++ bash

# Build server
RUN npm ci && npm run build && npm prune --production

# Build client
RUN cd client && \
    export NODE_OPTIONS=--openssl-legacy-provider && \
    npm ci --ignore-scripts && \
    npm run build

RUN apk del npm-deps

# Prune dev artifacts (arm64-compatible, replaces node-prune)
RUN find node_modules -name "*.md" -delete 2>/dev/null || true && \
    find node_modules -name "*.ts" ! -name "*.d.ts" -delete 2>/dev/null || true && \
    find node_modules \( -name "test" -o -name "tests" -o -name "example" -o -name "examples" \) \
      -type d -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf node_modules/rxjs/src/ \
           node_modules/rxjs/bundles/ \
           node_modules/rxjs/_esm5/ \
           node_modules/rxjs/_esm2015/ 2>/dev/null || true

FROM node:24-alpine3.23

ENV DATABASE_HOST=127.0.0.1
ENV DATABASE_PORT=5432
ENV DATABASE_NAME=fabricexplorer
ENV DATABASE_USERNAME=hppoc
ENV DATABASE_PASSWD=password
ENV EXPLORER_APP_ROOT=app
ENV DEFAULT_WORKDIR=/opt
ENV EXPLORER_APP_PATH=$DEFAULT_WORKDIR/explorer

WORKDIR $EXPLORER_APP_PATH

COPY . .
COPY --from=build $EXPLORER_APP_PATH/dist ./app/
COPY --from=build $EXPLORER_APP_PATH/client/build ./client/build/
COPY --from=build $EXPLORER_APP_PATH/node_modules ./node_modules/

EXPOSE 8080

CMD npm run app-start && tail -f /dev/null
