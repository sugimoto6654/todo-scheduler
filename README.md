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

## LINE Bot Configuration

The application supports daily task notifications via LINE Bot.

### Environment Variables

Create a `.env` file in the `backend/` directory with the following variables:

```env
# LINE Bot Configuration
LINE_CHANNEL_ACCESS_TOKEN=your_line_channel_access_token_here
LINE_USER_ID=your_line_user_id_here

# Scheduler Configuration (optional)
NOTIFICATION_SCHEDULER_ENABLED=true

# OpenAI Configuration (existing)
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4o-2024-08-06
CHAT_MOCK_MODE=false
```

### LINE Bot Setup

1. Create a LINE Bot channel in the [LINE Developers Console](https://developers.line.biz/console/)
2. Get your Channel Access Token
3. Get your User ID (you can use the LINE official account to get this)
4. Set the environment variables in the `.env` file

### Features

- **Daily Notifications**: Automatically sends task list every day at 8:00 AM (JST)
- **Debug Endpoints**: 
  - `POST /debug/send-notification` - Send test notification immediately
  - `GET /debug/scheduler-status` - Check scheduler status and jobs
