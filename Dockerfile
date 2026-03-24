ARG NODE=node:20-alpine

# =============================================================
# STAGE 1: BUILD
# Install deps and compile the Next.js app into a standalone bundle.
# Alpine keeps the image small and the attack surface low.
# =============================================================
FROM $NODE AS build

# Keep base image packages up to date (security hygiene)
RUN apk update && apk upgrade

WORKDIR /app

# Copy lockfile + manifest first so Docker can cache the node_modules layer.
# Docker only re-runs npm ci when these two files change.
COPY package*.json ./
RUN npm ci

# Copy the rest of the source code
COPY . .

# NEXT_PUBLIC_ vars are baked into the client bundle at build time —
# they must be set here, not at runtime.
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

ENV NODE_ENV=production

# Requires output: 'standalone' in next.config.mjs
RUN npm run build

# =============================================================
# STAGE 2: PRODUCTION IMAGE
# Copy only compiled output — no dev dependencies, minimal size.
# =============================================================
FROM $NODE AS production

RUN apk update && apk upgrade

WORKDIR /app

# Non-root system user — running as root inside a container is a security risk
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# The standalone output bundles server.js with a minimal node_modules
COPY --from=build --chown=nextjs:nodejs /app/.next/standalone ./
# Static assets (JS chunks, CSS)
COPY --from=build --chown=nextjs:nodejs /app/.next/static ./.next/static
# Public folder (favicon, open-graph images, etc.)
COPY --from=build --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]