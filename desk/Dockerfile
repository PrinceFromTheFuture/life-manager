# Chromium has to live in the image: whatsapp-web.js drives WhatsApp Web.
# Session files stay on a volume so a redeploy does not ask for a new QR.

FROM oven/bun:1.3.3

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        chromium \
        fonts-liberation \
        fonts-noto-color-emoji \
        fonts-freefont-ttf \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

COPY index.ts tsconfig.json ./

ENV PORT=5555
EXPOSE 5555

CMD ["bun", "index.ts"]
