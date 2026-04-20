# ---------- Build stage ----------
FROM node:20-alpine AS build
WORKDIR /app

# SWC & some libs on Alpine benefit from these
RUN apk add --no-cache libc6-compat python3 make g++

# Use the exact pnpm version from package.json `packageManager`
RUN corepack enable

# Copy only files needed to reproduce lockfile resolution
COPY package.json pnpm-lock.yaml ./
# If present in your repo, uncomment any of these:
# COPY .npmrc ./
# COPY pnpm-workspace.yaml ./
# COPY .pnpmfile.cjs ./
# COPY .pnpmfile.mjs ./

# Activate pinned pnpm (matches your lockfile)
RUN node -e "const pm=require('./package.json').packageManager; if(pm) console.log('Activating', pm)" \
 && corepack prepare "$(node -p "require('./package.json').packageManager")" --activate || true

# Faster, cache-friendly flow: fetch then offline install
RUN pnpm fetch
# Copy source to run an offline install + build
COPY . .
RUN pnpm install --offline --frozen-lockfile

# Build Next.js (outputs .next/)
RUN pnpm build

# ---------- Runtime stage (non-standalone: keep node_modules) ----------
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app

# Copy what runtime needs
COPY --from=build /app/package.json /app/pnpm-lock.yaml ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
# If you serve any static files from /public only, nothing else needed

# Good defaults for Next in Docker
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

EXPOSE 3000
CMD ["node_modules/.bin/next", "start", "-p", "3000"]