# API Reference

## Overview

This backend is API-first and intended primarily for a mobile client.

Current public API base:

- `/api/v1`

## Response Shape

Successful responses use:

```json
{
  "data": {}
}
```

Error responses use:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Not Found",
    "status": 404
  }
}
```

## Current Endpoints

### `GET /api/v1`

Returns API metadata and the currently available endpoints.

Example response:

```json
{
  "data": {
    "name": "reseller",
    "version": "v1",
    "docs_path": "/docs/API.md",
    "endpoints": [
      {
        "method": "GET",
        "path": "/api/v1",
        "description": "Returns API metadata and the list of currently available endpoints."
      },
      {
        "method": "GET",
        "path": "/api/v1/health",
        "description": "Returns service health and application version information."
      }
    ]
  }
}
```

### `GET /api/v1/health`

Returns a simple health payload for uptime checks and local verification.

Example response:

```json
{
  "data": {
    "name": "reseller",
    "status": "ok",
    "version": "0.1.0"
  }
}
```

### `POST /api/v1/auth/register`

Creates a user account and returns a bearer token for the mobile client.

Request body:

```json
{
  "email": "seller@example.com",
  "password": "very-secure-password",
  "device_name": "iPhone"
}
```

Response:

```json
{
  "data": {
    "token": "token-value",
    "token_type": "Bearer",
    "expires_at": "2026-04-28T18:00:00Z",
    "user": {
      "id": 1,
      "email": "seller@example.com",
      "confirmed_at": null
    }
  }
}
```

Validation failures return `422` with field-level details.

### `POST /api/v1/auth/login`

Authenticates a user with email and password and returns a new bearer token.

Request body:

```json
{
  "email": "seller@example.com",
  "password": "very-secure-password",
  "device_name": "Pixel"
}
```

Invalid credentials return:

```json
{
  "error": {
    "code": "unauthorized",
    "detail": "Invalid email or password",
    "status": 401
  }
}
```

### `GET /api/v1/me`

Returns the authenticated user for the current bearer token.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "user": {
      "id": 1,
      "email": "seller@example.com",
      "confirmed_at": null
    }
  }
}
```

## Conventions

- New endpoints should be added under the versioned `/api/v1` namespace.
- When new endpoints are introduced, update this file in the same feature commit.
- Keep error payloads stable for mobile clients.
- Prefer explicit, machine-readable statuses and error codes.
- Protected endpoints should use bearer-token authentication.
