FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install with legacy peer deps (ignores conflicts)
RUN npm install --legacy-peer-deps --only=production && npm cache clean --force

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001
USER nextjs

# Railway provides PORT environment variable
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000} || exit 1

# Start the application
CMD ["sh", "-c", "npm start -- --port ${PORT:-3000}"]