# Todo Scheduler

This is a simple Todo management web application.

- **Backend:** Python + Flask
- **Frontend:** Flutter Web

## Development

### Requirements
- Docker / Docker Compose

### Running locally

```bash
# build and start containers
docker-compose up --build

# backend will listen on http://localhost:5000
# frontend (Flutter web) will be served from http://localhost:8080
```

When developing the Flutter frontend locally with the SDK, make sure to set
`API_BASE=/api` so that requests are proxied to the backend service defined in
the Docker Compose setup.
