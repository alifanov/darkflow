FROM node:24-alpine AS base
RUN corepack enable && corepack prepare pnpm@10 --activate

FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
COPY prisma/ ./prisma/
RUN pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.pnpm ./node_modules/.pnpm
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=builder /app/node_modules/prisma ./node_modules/prisma
COPY --from=builder /app/node_modules/.bin ./node_modules/.bin

# Create missing @prisma symlinks that the prisma CLI needs at runtime
# (standalone output only copies @prisma/client; engines and config are CLI-only)
RUN for pkg in engines config; do \
      dir=$(ls /app/node_modules/.pnpm/ | grep "^@prisma+${pkg}@" | head -1); \
      [ -n "$dir" ] && ln -sf "/app/node_modules/.pnpm/${dir}/node_modules/@prisma/${pkg}" \
                              "/app/node_modules/@prisma/${pkg}"; \
    done

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/docker-entrypoint.sh"]
