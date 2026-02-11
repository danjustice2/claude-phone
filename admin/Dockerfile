FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY . .

EXPOSE ${ADMIN_PORT:-8080}

CMD ["node", "server.js"]
