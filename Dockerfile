FROM golang:1.25.0-alpine AS build

RUN apk update && apk add --no-cache \
    git \
    wget \
    ca-certificates \
    build-base \
    libjpeg-turbo-dev \
    libwebp-dev

WORKDIR /build

# Copiar apenas arquivos de dependências primeiro para cachear o download.
COPY go.mod go.sum ./

# whatsmeow agora vem do proxy oficial (go.mau.fi/whatsmeow, sem replace local).
RUN go mod download

# Copiar o restante do código.
COPY . .

# O fork publicado ficou sem dois arquivos rastreados pelo Dockerfile/routes.go.
# Restaura somente os arquivos ausentes a partir da revisão upstream compatível.
ARG UPSTREAM_COMMIT=9337afc47e10b86cc896a6f432240e40fee95dd1
RUN set -eux; \
    if [ ! -s cmd/evolution-go/main.go ]; then \
        mkdir -p cmd/evolution-go; \
        wget -O cmd/evolution-go/main.go \
          "https://raw.githubusercontent.com/evolution-foundation/evolution-go/${UPSTREAM_COMMIT}/cmd/evolution-go/main.go"; \
    fi; \
    if [ ! -s pkg/server/handler/server_handler.go ]; then \
        mkdir -p pkg/server/handler; \
        wget -O pkg/server/handler/server_handler.go \
          "https://raw.githubusercontent.com/evolution-foundation/evolution-go/${UPSTREAM_COMMIT}/pkg/server/handler/server_handler.go"; \
    fi; \
    test -s cmd/evolution-go/main.go; \
    test -s pkg/server/handler/server_handler.go

ARG VERSION=dev
RUN CGO_ENABLED=1 go build -ldflags "-X main.version=${VERSION}" -o server ./cmd/evolution-go

FROM alpine:3.19.1 AS final

# poppler-utils provides pdftoppm, usado para thumbnails de documentos PDF.
RUN apk update && apk add --no-cache tzdata ffmpeg libjpeg-turbo libwebp poppler-utils

WORKDIR /app

COPY --from=build /build/server .
COPY --from=build /build/manager/dist ./manager/dist
COPY --from=build /build/VERSION ./VERSION

ENV TZ=America/Sao_Paulo

ENTRYPOINT ["/app/server"]
