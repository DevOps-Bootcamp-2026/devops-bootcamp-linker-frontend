ARG NODE=node:20-alpine

# Stage 1: Build the application
FROM $NODE AS build

RUN apk update && apk upgrade

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies using npm ci for faster, more reliable build
RUN npm ci

# Copy the rest of the application source code
COPY . .
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NODE_ENV=production

# Build the application
RUN npm run build

# Stage 2: Production image
FROM $NODE AS production

RUN apk update && apk upgrade

WORKDIR /app

# Create a non-root user and group
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy the standalone output
COPY --from=build --chown=nextjs:nodejs /app/.next/standalone ./
# Copy the public and static folders
COPY --from=build --chown=nextjs:nodejs /app/.next/static ./.next/static

COPY --from=build --chown=nextjs:nodejs /app/public ./public

# Set the user
USER nextjs

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["node", "server.js"]