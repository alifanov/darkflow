#!/bin/sh
set -e

# Run migrations before starting
node_modules/.bin/prisma migrate deploy

exec node server.js
