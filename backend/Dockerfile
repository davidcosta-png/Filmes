# Builder stage
FROM node:18-alpine AS builder
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm ci --production --silent

# Runtime stage
FROM node:18-alpine
WORKDIR /usr/src/app
ENV NODE_ENV=production
# copy node_modules from builder
COPY --from=builder /usr/src/app/node_modules ./node_modules
# copy app source
COPY . .
EXPOSE 4000
ENV JWT_SECRET=replace_with_secure_secret_in_production
CMD [ "node", "index.js" ]
