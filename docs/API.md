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

## Conventions

- New endpoints should be added under the versioned `/api/v1` namespace.
- When new endpoints are introduced, update this file in the same feature commit.
- Keep error payloads stable for mobile clients.
- Prefer explicit, machine-readable statuses and error codes.
