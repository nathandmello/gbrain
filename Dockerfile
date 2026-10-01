FROM oven/bun:1.4.2

WORKDIR /app

# Useful runtime packages for GBrain and Bun
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       git \
       libatomic1 \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN bun install --frozen-lockfile
RUN bun run build

EXPOSE 3131

CMD ["sh", "-c", "if [ ! -f \"$GBRAIN_HOME/.gbrain/config.json\" ]; then ./bin/gbrain init --non-interactive --no-embedding --db-only; fi; exec ./bin/gbrain serve --http --bind 0.0.0.0 --port 3131 --public-url \"https://$RAILWAY_PUBLIC_DOMAIN\" --suppress-bootstrap-token"]
