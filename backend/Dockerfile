FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package.json package-lock.json* ./
RUN npm install --production --silent

# Bundle app source
COPY . .

EXPOSE 4000

ENV NODE_ENV=production
# Default JWT secret - override via environment variable in production
ENV JWT_SECRET=replace_with_secure_secret_in_production

CMD [ "node", "index.js" ]

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 