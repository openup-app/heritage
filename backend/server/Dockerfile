FROM node:20-alpine3.19

ENV NODE_ENV $NODE_ENV
ENV BASE_URL $BASE_URL

# Source code
WORKDIR /srv/
RUN mkdir uploads
COPY package.json .
COPY package-lock.json .
RUN npm install

COPY . .

RUN npm run build

USER node
EXPOSE 8080
CMD [ "npm", "start" ]
