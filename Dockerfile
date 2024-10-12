FROM --platform=linux/amd64 golang:1.20

WORKDIR /app

RUN apt-get update && apt-get install -y git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o golang-demo

RUN go install github.com/cosmtrek/air@latest

EXPOSE 80

CMD ["air"]