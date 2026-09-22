# syntax=docker/dockerfile:1.7
FROM golang:1.25-alpine AS build
ENV GOPROXY=https://goproxy.cn,direct
WORKDIR /src
COPY go.mod ./
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/any2pcd .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates && adduser -D -H -u 1000 app
WORKDIR /work
COPY --from=build /out/any2pcd /usr/local/bin/any2pcd
USER app
ENTRYPOINT ["any2pcd"]
