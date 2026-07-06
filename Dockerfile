FROM node:20-slim

WORKDIR /home/user/app

COPY web/ /home/user/app/

RUN npm install

RUN npm run build

EXPOSE 7860

CMD ["npm", "start"]
