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
      },
      {
        "method": "GET",
        "path": "/api/v1/products",
        "description": "Lists products for the authenticated user."
      },
      {
        "method": "POST",
        "path": "/api/v1/products",
        "description": "Creates a product and optionally returns signed upload instructions."
      },
      {
        "method": "GET",
        "path": "/api/v1/products/:id",
        "description": "Returns one product for the authenticated user."
      },
      {
        "method": "POST",
        "path": "/api/v1/products/:id/finalize_uploads",
        "description": "Marks uploaded product images as ready for processing."
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

### `GET /api/v1/products`

Returns the authenticated user's products, newest first.

Required header:

```text
Authorization: Bearer <token>
```

Response:

```json
{
  "data": {
    "products": [
      {
        "id": 1,
        "status": "draft",
        "source": "manual",
        "title": "Vintage blazer",
        "brand": "Ralph Lauren",
        "category": "Blazers",
        "latest_processing_run": null,
        "description_draft": null,
        "images": []
      }
    ]
  }
}
```

### `POST /api/v1/products`

Creates a product. If `uploads` are included, the backend also creates `product_images`
placeholders and returns signed upload instructions.

Required header:

```text
Authorization: Bearer <token>
```

Request body without uploads:

```json
{
  "product": {
    "title": "Vintage blazer",
    "brand": "Ralph Lauren",
    "category": "Blazers"
  }
}
```

Request body with uploads:

```json
{
  "product": {
    "title": "Nike Air Max",
    "brand": "Nike",
    "category": "Sneakers"
  },
  "uploads": [
    {
      "filename": "shoe-1.jpg",
      "content_type": "image/jpeg",
      "byte_size": 345678
    }
  ]
}
```

Response:

```json
{
  "data": {
    "product": {
      "id": 1,
      "status": "uploading",
      "source": "manual",
      "title": "Nike Air Max",
      "brand": "Nike",
      "category": "Sneakers",
      "latest_processing_run": null,
      "description_draft": null,
      "images": [
        {
          "id": 1,
          "kind": "original",
          "position": 1,
          "storage_key": "users/1/products/1/originals/uuid.jpg",
          "content_type": "image/jpeg",
          "processing_status": "pending_upload",
          "original_filename": "shoe-1.jpg"
        }
      ]
    },
    "upload_instructions": [
      {
        "image_id": 1,
        "storage_key": "users/1/products/1/originals/uuid.jpg",
        "method": "PUT",
        "upload_url": "https://bucket.example.tigris.dev/...",
        "headers": {
          "content-type": "image/jpeg"
        },
        "expires_at": "2026-03-29T18:40:00Z"
      }
    ]
  }
}
```

Upload validation failures return `422`.

### `GET /api/v1/products/:id`

Returns one product for the authenticated user.

Required header:

```text
Authorization: Bearer <token>
```

Unknown or unauthorized product IDs return:

```json
{
  "error": {
    "code": "not_found",
    "detail": "Product not found",
    "status": 404
  }
}
```

### `POST /api/v1/products/:id/finalize_uploads`

Marks one or more pending upload placeholders as uploaded and transitions the product
to `processing` once all expected original images are finalized.

Required header:

```text
Authorization: Bearer <token>
```

Request body:

```json
{
  "uploads": [
    {
      "id": 1,
      "checksum": "abc123",
      "width": 1200,
      "height": 1600
    }
  ]
}
```

Response:

```json
{
  "data": {
    "product": {
      "id": 1,
      "status": "processing",
      "latest_processing_run": {
        "id": 12,
        "status": "queued",
        "step": "queued"
      },
      "description_draft": null,
      "images": [
        {
          "id": 1,
          "processing_status": "processing",
          "checksum": "abc123",
          "width": 1200,
          "height": 1600
        }
      ]
    },
    "finalized_images": [
      {
        "id": 1,
        "processing_status": "uploaded"
      }
    ],
    "processing_run": {
      "id": 12,
      "status": "queued",
      "step": "queued",
      "payload": {}
    }
  }
}
```

Current behavior notes:

- the finalize endpoint immediately creates a `product_processing_run`
- in production-style async execution, the returned run is typically still `queued` or `running`
- the worker uses finalized original uploads as Gemini and SerpApi inputs, using `TIGRIS_BUCKET_URL` as the public image base
- when recognition finishes, the product moves to `ready` or `review`
- when description generation finishes, the product may also include a `description_draft` object with AI-authored base copy
- on success, in-flight images move from `processing` to `ready`
- on worker failure, in-flight images move from `processing` to `failed` and the product falls back to `review`

### Product Processing Status

Product payloads now expose `latest_processing_run` so clients can track background progress without a separate worker endpoint yet.

Example:

```json
{
  "latest_processing_run": {
    "id": 12,
    "status": "completed",
    "step": "description_generated",
    "started_at": "2026-03-29T20:30:00Z",
    "finished_at": "2026-03-29T20:30:01Z",
    "error_code": null,
    "error_message": null,
    "payload": {
      "pipeline_status": "recognized",
      "review_required": false,
      "description_draft": {
        "id": 9,
        "status": "generated",
        "suggested_title": "Nike Air Max 90",
        "short_description": "Classic Nike Air Max 90 sneakers in white mesh."
      },
      "final": {
        "brand": "Nike",
        "category": "Sneakers",
        "possible_model": "Air Max 90",
        "confidence_score": 0.91,
        "needs_review": false
      }
    }
  }
}
```

Run status values currently used:

- `queued`
- `running`
- `completed`
- `failed`

The `step` field is used to show finer-grained progress such as `queued`, `prepare_images`, `recognition_completed`, and `description_generated`.

### Description Drafts

Product payloads may include a `description_draft` object after AI processing completes:

```json
{
  "description_draft": {
    "id": 9,
    "status": "generated",
    "provider": "gemini",
    "model": "gemini-2.5-flash",
    "suggested_title": "Nike Air Max 90",
    "short_description": "Classic Nike Air Max 90 sneakers in white mesh.",
    "long_description": "White Nike Air Max 90 sneakers with breathable mesh and a visible air unit.",
    "key_features": ["Visible air unit", "Mesh upper"],
    "seo_keywords": ["nike air max 90", "white sneakers"],
    "missing_details_warning": null
  }
}
```

These drafts are AI-authored base copy and are stored separately from editable product fields.

If the provided image IDs do not belong to the selected product, the API returns:

```json
{
  "error": {
    "code": "invalid_uploads",
    "detail": "Uploads must belong to the selected product",
    "status": 422
  }
}
```

## Conventions

- New endpoints should be added under the versioned `/api/v1` namespace.
- When new endpoints are introduced, update this file in the same feature commit.
- Keep error payloads stable for mobile clients.
- Prefer explicit, machine-readable statuses and error codes.
- Protected endpoints should use bearer-token authentication.
