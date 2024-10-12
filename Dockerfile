FROM golang:1.20-alpine

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o golang-demo

RUN go install github.com/cosmtrek/air@latest

EXPOSE 80

CMD ["air"]