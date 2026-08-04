# 塑身工坊后端镜像 — 多阶段构建
# 无需本机 Go 环境，docker compose up 即构建

# ---- 构建阶段 ----
FROM golang:1.24-alpine AS builder
WORKDIR /app

# 复制全部源码后统一解析依赖并构建（无本机 Go 环境也可一键构建）
# 大陆网络使用七牛 Go 代理加速依赖下载
ENV GOPROXY=https://goproxy.cn,direct
COPY . .
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

# ---- 运行阶段 ----
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D app
WORKDIR /app
COPY --from=builder /server /app/server
COPY migrations /app/migrations

USER app
EXPOSE 8080
ENTRYPOINT ["/app/server"]
