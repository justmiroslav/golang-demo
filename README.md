# Golang Demo

## Build binary

```sh
GOOS=linux GOARCH=amd64 go build -o golang-demo
chmod +x golang-demo
```

## Preconditions

1. Install and configure PostreSQL db
2. Create schema from file `db_schema.sql`

## Start program

```sh
DB_ENDPOINT=<db_endpoint> DB_PORT=5432 DB_USER=<user> DB_PASS=<password> DB_NAME=<db_name> ./golang-demo
```

## Use program examples
```sh
curl "http://localhost:80/ping?url=https://google.com" --header "Content-Type:application/text"
curl -X POST "http://localhost:80/video?id=1&title=Forest_Gump"
curl "http://localhost:80/videos"
curl "http://localhost:80/fibonacci?number=7"
curl "http://localhost:80/memory-leak"
```
