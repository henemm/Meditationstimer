# Übernommen aus loose-ends server/Dockerfile @ 24a6da6; angepasst: Build-Kontext ist die Repo-Wurzel (docker build -f server/Dockerfile .),
# damit Abschrift-Schema, Lieferformat-Schema, Übungskatalog und Prüfer (Contracts/) ins Image kommen. Anordnung wie im Repo: /app/server und /app/Contracts.
FROM node:26-slim
ENV NODE_ENV=production HOST=0.0.0.0 PORT=8080
WORKDIR /app/server
COPY --chown=node:node server/package.json server/package-lock.json ./
RUN npm ci --omit=dev
COPY --chown=node:node server/src ./src
COPY --chown=node:node server/migrations ./migrations
COPY --chown=node:node Contracts/transcript/transcript-v1.schema.json /app/Contracts/transcript/transcript-v1.schema.json
COPY --chown=node:node Contracts/transcript/transcript-v2.schema.json /app/Contracts/transcript/transcript-v2.schema.json
COPY --chown=node:node Contracts/schema/delivery-v1.schema.json /app/Contracts/schema/delivery-v1.schema.json
COPY --chown=node:node Contracts/catalog/builtin-exercises.json /app/Contracts/catalog/builtin-exercises.json
COPY --chown=node:node Contracts/validator/src /app/Contracts/validator/src
USER node
EXPOSE 8080
CMD ["node", "src/main.ts"]
