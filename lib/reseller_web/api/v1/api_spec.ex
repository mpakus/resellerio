defmodule ResellerWeb.API.V1.APISpec do
  alias ResellerWeb.Router

  @openapi_path "/api/v1/openapi.json"
  @docs_ui_path "/docs/api"
  @docs_repo_path "/docs/API.md"

  @operation_metadata %{
    {ResellerWeb.API.V1.RootController, :show} => %{
      summary: "Get API metadata",
      description: "Returns API metadata and the list of currently available endpoints.",
      tags: ["System"],
      public?: true
    },
    {ResellerWeb.API.V1.OpenAPIController, :show} => %{
      summary: "Get OpenAPI document",
      description: "Returns the OpenAPI 3.1 document for the current API version.",
      tags: ["System"],
      public?: true,
      success_schema: %{
        type: "object",
        additionalProperties: true
      }
    },
    {ResellerWeb.API.V1.HealthController, :show} => %{
      summary: "Get service health",
      description: "Returns service health and application version information.",
      tags: ["System"],
      public?: true
    },
    {ResellerWeb.API.V1.AuthController, :register} => %{
      summary: "Register an account",
      description: "Creates a user account and returns a bearer token.",
      tags: ["Authentication"],
      public?: true,
      request_body: %{
        required: true,
        description: "Registration payload",
        example: %{
          email: "seller@example.com",
          password: "very-secure-password",
          device_name: "iPhone",
          selected_marketplaces: ["ebay", "depop", "poshmark"]
        }
      }
    },
    {ResellerWeb.API.V1.AuthController, :login} => %{
      summary: "Log in",
      description: "Authenticates a user and returns a bearer token.",
      tags: ["Authentication"],
      public?: true,
      request_body: %{
        required: true,
        description: "Login payload",
        example: %{
          email: "seller@example.com",
          password: "very-secure-password",
          device_name: "iPhone"
        }
      },
      errors: [:bad_request, :unauthorized]
    },
    {ResellerWeb.API.V1.MeController, :show} => %{
      summary: "Get current user",
      description: "Returns the authenticated user and marketplace settings.",
      tags: ["User"]
    },
    {ResellerWeb.API.V1.MeController, :update} => %{
      summary: "Update current user",
      description: "Updates the authenticated user's marketplace settings.",
      tags: ["User"],
      request_body: %{
        required: true,
        description: "User marketplace preferences",
        example: %{
          user: %{
            selected_marketplaces: ["ebay", "mercari", "etsy"]
          }
        }
      },
      errors: [:unauthorized, :validation]
    },
    {ResellerWeb.API.V1.MeController, :usage} => %{
      summary: "Get monthly usage",
      description: "Returns monthly usage counters, plan limits, and addon credits.",
      tags: ["User"]
    },
    {ResellerWeb.API.V1.ProductTabController, :index} => %{
      summary: "List product tabs",
      description: "Lists seller-defined product tabs for the authenticated user.",
      tags: ["Product Tabs"]
    },
    {ResellerWeb.API.V1.ProductTabController, :create} => %{
      summary: "Create product tab",
      description: "Creates one seller-defined product tab.",
      tags: ["Product Tabs"],
      request_body: %{
        required: true,
        description: "Product tab payload",
        example: %{
          product_tab: %{
            name: "New arrivals"
          }
        }
      },
      response_status: "201",
      errors: [:unauthorized, :validation]
    },
    {ResellerWeb.API.V1.ProductTabController, :update} => %{
      summary: "Update product tab",
      description: "Updates one seller-defined product tab.",
      tags: ["Product Tabs"],
      request_body: %{
        required: true,
        description: "Product tab payload",
        example: %{
          product_tab: %{
            name: "Summer edit"
          }
        }
      },
      errors: [:unauthorized, :not_found, :validation]
    },
    {ResellerWeb.API.V1.ProductTabController, :delete} => %{
      summary: "Delete product tab",
      description: "Deletes one seller-defined product tab.",
      tags: ["Product Tabs"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.StorefrontController, :show} => %{
      summary: "Get storefront",
      description:
        "Returns the authenticated user's storefront configuration and the available theme presets.",
      tags: ["Storefront"]
    },
    {ResellerWeb.API.V1.StorefrontController, :upsert} => %{
      summary: "Create or update storefront",
      description:
        "Creates or updates the authenticated user's storefront and returns the available theme presets.",
      tags: ["Storefront"],
      request_body: %{
        required: true,
        description: "Storefront payload",
        example: %{
          storefront: %{
            slug: "vintage-vault",
            title: "Vintage Vault",
            description: "Curated vintage and designer pieces",
            theme_id: "desert-clay"
          }
        }
      },
      errors: [:unauthorized, :bad_request, :validation]
    },
    {ResellerWeb.API.V1.StorefrontController, :list_pages} => %{
      summary: "List storefront pages",
      description: "Lists the authenticated user's storefront pages in display order.",
      tags: ["Storefront"]
    },
    {ResellerWeb.API.V1.StorefrontController, :create_page} => %{
      summary: "Create storefront page",
      description: "Creates one storefront page.",
      tags: ["Storefront"],
      request_body: %{
        required: true,
        description: "Storefront page payload",
        example: %{
          page: %{
            title: "About",
            slug: "about",
            body: "We source collectible pieces with verified condition notes."
          }
        }
      },
      response_status: "201",
      errors: [:unauthorized, :bad_request, :validation]
    },
    {ResellerWeb.API.V1.StorefrontController, :update_page} => %{
      summary: "Update storefront page",
      description: "Updates one storefront page.",
      tags: ["Storefront"],
      request_body: %{
        required: true,
        description: "Storefront page payload",
        example: %{
          page: %{
            title: "Shipping",
            body: "Orders ship within two business days."
          }
        }
      },
      errors: [:unauthorized, :bad_request, :not_found, :validation]
    },
    {ResellerWeb.API.V1.StorefrontController, :delete_page} => %{
      summary: "Delete storefront page",
      description: "Deletes one storefront page.",
      tags: ["Storefront"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.StorefrontController, :reorder_pages} => %{
      summary: "Reorder storefront pages",
      description:
        "Sets display positions for storefront pages using an ordered list of page IDs.",
      tags: ["Storefront"],
      request_body: %{
        required: true,
        description: "Page id order",
        example: %{
          page_ids: [7, 5, 6]
        }
      },
      errors: [:unauthorized, :not_found, :unprocessable, :bad_request]
    },
    {ResellerWeb.API.V1.StorefrontController, :prepare_asset_upload} => %{
      summary: "Prepare storefront asset upload",
      description:
        "Creates or replaces a storefront logo or header asset record and returns a signed upload instruction.",
      tags: ["Storefront"],
      request_body: %{
        required: true,
        description: "Storefront asset upload payload",
        example: %{
          asset: %{
            filename: "logo.png",
            content_type: "image/png",
            byte_size: 48_000,
            width: 400,
            height: 400
          }
        }
      },
      errors: [:unauthorized, :bad_request, :validation, :unprocessable]
    },
    {ResellerWeb.API.V1.StorefrontController, :delete_asset} => %{
      summary: "Delete storefront asset",
      description: "Deletes one storefront branding asset by kind.",
      tags: ["Storefront"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.InquiryController, :index} => %{
      summary: "List inquiries",
      description:
        "Lists storefront inquiries for the authenticated user with search and pagination.",
      tags: ["Inquiries"]
    },
    {ResellerWeb.API.V1.InquiryController, :delete} => %{
      summary: "Delete inquiry",
      description: "Deletes one storefront inquiry for the authenticated user.",
      tags: ["Inquiries"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :index} => %{
      summary: "List products",
      description:
        "Lists products for the authenticated user with filtering, sorting, and pagination.",
      tags: ["Products"],
      query_parameters: [
        %{
          name: "page",
          description: "Page number for paginated results.",
          schema: %{type: "integer", minimum: 1}
        },
        %{
          name: "page_size",
          description: "Number of products per page.",
          schema: %{type: "integer", minimum: 1}
        },
        %{
          name: "status",
          description: "Filter by product status.",
          schema: %{type: "string"}
        },
        %{
          name: "query",
          description: "Free-text search query.",
          schema: %{type: "string"}
        },
        %{
          name: "product_tab_id",
          description: "Filter by product tab id.",
          schema: %{type: "integer"}
        },
        %{
          name: "updated_from",
          description: "Filter by update date lower bound in ISO-8601 date format.",
          schema: %{type: "string", format: "date"}
        },
        %{
          name: "updated_to",
          description: "Filter by update date upper bound in ISO-8601 date format.",
          schema: %{type: "string", format: "date"}
        },
        %{
          name: "sort",
          description: "Sort field.",
          schema: %{type: "string"}
        },
        %{
          name: "dir",
          description: "Sort direction.",
          schema: %{type: "string", enum: ["asc", "desc"]}
        }
      ]
    },
    {ResellerWeb.API.V1.ProductController, :create} => %{
      summary: "Create product",
      description: "Creates a product and optionally returns signed upload instructions.",
      tags: ["Products"],
      request_body: %{
        required: false,
        description: "Product payload and optional upload descriptors",
        example: %{
          product: %{
            title: "Vintage Coach bag",
            brand: "Coach"
          },
          uploads: [
            %{
              filename: "front.jpg",
              content_type: "image/jpeg"
            }
          ]
        }
      },
      response_status: "201",
      errors: [:unauthorized, :validation]
    },
    {ResellerWeb.API.V1.ProductController, :show} => %{
      summary: "Get product",
      description: "Returns one product for the authenticated user.",
      tags: ["Products"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :update} => %{
      summary: "Update product",
      description:
        "Updates seller-managed product fields, storefront publication flags, and marketplace external URLs.",
      tags: ["Products"],
      request_body: %{
        required: false,
        description: "Seller-managed product fields",
        example: %{
          product: %{
            title: "Vintage Coach shoulder bag",
            tags: ["vintage", "leather"],
            storefront_enabled: true
          },
          marketplace_external_urls: %{
            ebay: "https://www.ebay.com/itm/1234567890"
          }
        }
      },
      errors: [:unauthorized, :not_found, :validation]
    },
    {ResellerWeb.API.V1.ProductController, :delete} => %{
      summary: "Delete product",
      description: "Deletes one product and its related records.",
      tags: ["Products"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :prepare_uploads} => %{
      summary: "Prepare product uploads",
      description:
        "Creates upload placeholders for an existing product and returns signed upload instructions.",
      tags: ["Products"],
      request_body: %{
        required: true,
        description: "List of upload intents",
        example: %{
          uploads: [
            %{
              filename: "side.jpg",
              content_type: "image/jpeg",
              byte_size: 345_678
            }
          ]
        }
      },
      errors: [:unauthorized, :not_found, :validation, :unprocessable, :limit_exceeded]
    },
    {ResellerWeb.API.V1.ProductController, :finalize_uploads} => %{
      summary: "Finalize uploads",
      description: "Marks uploaded product images as ready for processing.",
      tags: ["Products"],
      request_body: %{
        required: false,
        description: "List of uploaded files to finalize",
        example: %{
          uploads: [
            %{
              storage_key: "uploads/products/123/front.jpg"
            }
          ]
        }
      },
      errors: [:unauthorized, :not_found, :validation, :unprocessable, :limit_exceeded]
    },
    {ResellerWeb.API.V1.ProductController, :reprocess} => %{
      summary: "Reprocess product",
      description: "Restarts the core AI pipeline for one product.",
      tags: ["Products"],
      response_status: "202",
      errors: [:unauthorized, :not_found, :validation, :unprocessable, :limit_exceeded]
    },
    {ResellerWeb.API.V1.ProductController, :generate_lifestyle_images} => %{
      summary: "Generate lifestyle images",
      description: "Starts manual lifestyle-image generation for a review-ready product.",
      tags: ["Lifestyle Images"],
      request_body: %{
        required: false,
        description: "Optional lifestyle scene selection",
        example: %{
          scene_key: "modern-living-room"
        }
      },
      response_status: "202",
      errors: [:unauthorized, :not_found, :validation, :unprocessable, :limit_exceeded]
    },
    {ResellerWeb.API.V1.ProductController, :lifestyle_generation_runs} => %{
      summary: "List lifestyle generation runs",
      description: "Lists dedicated lifestyle-image generation runs for one product.",
      tags: ["Lifestyle Images"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :approve_generated_image} => %{
      summary: "Approve generated image",
      description: "Marks one generated lifestyle preview as seller-approved.",
      tags: ["Lifestyle Images"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :delete_generated_image} => %{
      summary: "Delete generated image",
      description: "Deletes one generated lifestyle preview.",
      tags: ["Lifestyle Images"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :delete_image} => %{
      summary: "Delete product image",
      description: "Deletes one uploaded product image and its processed variants.",
      tags: ["Product Images"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :update_image_storefront} => %{
      summary: "Update storefront image settings",
      description: "Updates storefront visibility and display order for one product image.",
      tags: ["Product Images"],
      request_body: %{
        required: true,
        description: "Storefront visibility and ordering values",
        example: %{
          storefront_visible: true,
          storefront_position: 1
        }
      },
      errors: [:unauthorized, :not_found, :validation]
    },
    {ResellerWeb.API.V1.ProductController, :reorder_storefront_images} => %{
      summary: "Reorder storefront images",
      description: "Sets storefront_position for an ordered list of image IDs.",
      tags: ["Product Images"],
      request_body: %{
        required: true,
        description: "Image id order",
        example: %{
          image_ids: [11, 12, 13]
        }
      },
      errors: [:unauthorized, :not_found, :unprocessable, :bad_request]
    },
    {ResellerWeb.API.V1.ProductController, :mark_sold} => %{
      summary: "Mark product sold",
      description: "Marks one product as sold.",
      tags: ["Products"],
      request_body: %{
        required: false,
        description: "Optional seller-managed sold fields",
        example: %{
          product: %{
            sold_price: "185.00",
            sold_at: "2026-04-01"
          }
        }
      },
      errors: [:unauthorized, :not_found, :validation]
    },
    {ResellerWeb.API.V1.ProductController, :archive} => %{
      summary: "Archive product",
      description: "Archives one product.",
      tags: ["Products"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ProductController, :unarchive} => %{
      summary: "Unarchive product",
      description: "Restores one archived product.",
      tags: ["Products"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ExportController, :create} => %{
      summary: "Request export",
      description:
        "Queues a filtered ZIP export for the authenticated user with optional saved name and filter params.",
      tags: ["Exports"],
      request_body: %{
        required: false,
        description: "Optional export name and filters",
        example: %{
          export: %{
            name: "Poshmark-ready",
            filters: %{
              status: "ready",
              product_tab_id: 42
            }
          }
        }
      },
      response_status: "202",
      errors: [:unauthorized, :validation, :unprocessable]
    },
    {ResellerWeb.API.V1.ExportController, :show} => %{
      summary: "Get export",
      description: "Returns one export request for the authenticated user.",
      tags: ["Exports"],
      errors: [:unauthorized, :not_found]
    },
    {ResellerWeb.API.V1.ImportController, :create} => %{
      summary: "Request import",
      description:
        "Queues a ResellerIO ZIP import for the authenticated user using Products.xls, manifest.json, and images.",
      tags: ["Imports"],
      request_body: %{
        required: true,
        description: "Import payload",
        example: %{
          import: %{
            upload_key: "imports/2026-04-01/batch.zip",
            filename: "batch.zip"
          }
        }
      },
      response_status: "202",
      errors: [:unauthorized, :validation, :unprocessable]
    },
    {ResellerWeb.API.V1.ImportController, :show} => %{
      summary: "Get import",
      description: "Returns one import request for the authenticated user.",
      tags: ["Imports"],
      errors: [:unauthorized, :not_found]
    }
  }

  def endpoint_index do
    api_routes()
    |> Enum.map(fn route ->
      metadata = metadata_for(route)

      %{
        method: route_method(route),
        path: route.path,
        description: metadata.description
      }
    end)
  end

  def root_payload do
    %{
      name: "resellerio",
      version: api_version(),
      docs_path: @docs_repo_path,
      docs_ui_path: @docs_ui_path,
      openapi_path: @openapi_path,
      endpoints: endpoint_index()
    }
  end

  def openapi_document do
    %{
      openapi: "3.1.0",
      info: %{
        title: "ResellerIO API",
        version: api_version(),
        description:
          "API-first Phoenix backend for product intake, AI processing, storefront management, exports, and imports."
      },
      servers: [
        %{
          url: "/",
          description: "Current environment"
        }
      ],
      externalDocs: %{
        description: "Interactive API docs",
        url: @docs_ui_path
      },
      tags: tags(),
      paths: paths(),
      components: components()
    }
  end

  def docs_ui_path, do: @docs_ui_path
  def openapi_path, do: @openapi_path

  defp api_routes do
    Router.__routes__()
    |> Enum.filter(fn route -> String.starts_with?(route.path, "/api/v1") end)
    |> Enum.uniq_by(fn route -> {route.verb, route.path, route.plug, route.plug_opts} end)
  end

  defp tags do
    api_routes()
    |> Enum.map(&metadata_for/1)
    |> Enum.flat_map(&Map.get(&1, :tags, []))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn name -> %{name: name} end)
  end

  defp paths do
    api_routes()
    |> Enum.reduce(%{}, fn route, acc ->
      openapi_path = openapi_path_for(route.path)
      operation = operation_spec(route)
      method = route.verb |> Atom.to_string() |> String.downcase()

      Map.update(acc, openapi_path, %{method => operation}, &Map.put(&1, method, operation))
    end)
  end

  defp operation_spec(route) do
    metadata = metadata_for(route)

    %{
      tags: metadata.tags,
      summary: metadata.summary,
      description: metadata.description,
      operationId: operation_id(route),
      parameters: parameters(route, metadata),
      responses: responses(route, metadata)
    }
    |> maybe_put_security(metadata)
    |> maybe_put_request_body(metadata)
  end

  defp parameters(route, metadata) do
    path_params =
      route.path
      |> extract_path_params()
      |> Enum.map(&path_parameter(&1, metadata))

    query_params =
      metadata
      |> Map.get(:query_parameters, [])
      |> Enum.map(fn parameter ->
        %{
          name: parameter.name,
          in: "query",
          required: false,
          description: parameter.description,
          schema: parameter.schema
        }
      end)

    path_params ++ query_params
  end

  defp responses(route, metadata) do
    success_status = Map.get(metadata, :response_status, default_success_status(route))

    metadata
    |> errors_for(route)
    |> Enum.reduce(
      %{
        success_status => %{
          description: success_description(success_status),
          content: json_content(Map.get(metadata, :success_schema, schema_ref("SuccessEnvelope")))
        }
      },
      fn error_key, acc -> Map.put(acc, error_status(error_key), error_response(error_key)) end
    )
  end

  defp errors_for(metadata, route) do
    defaults =
      []
      |> maybe_add_unauthorized(metadata)
      |> maybe_add_not_found(route)

    Map.get(metadata, :errors, defaults)
  end

  defp maybe_add_unauthorized(errors, %{public?: true}), do: errors
  defp maybe_add_unauthorized(errors, _metadata), do: [:unauthorized | errors]

  defp maybe_add_not_found(errors, route) do
    if extract_path_params(route.path) == [] do
      errors
    else
      errors ++ [:not_found]
    end
  end

  defp error_status(:bad_request), do: "400"
  defp error_status(:unauthorized), do: "401"
  defp error_status(:limit_exceeded), do: "402"
  defp error_status(:not_found), do: "404"
  defp error_status(:validation), do: "422"
  defp error_status(:unprocessable), do: "422"

  defp error_response(:bad_request) do
    %{
      description: "Bad request",
      content: json_content(schema_ref("ErrorEnvelope"))
    }
  end

  defp error_response(:unauthorized) do
    %{
      description: "Missing or invalid bearer token",
      content: json_content(schema_ref("ErrorEnvelope"))
    }
  end

  defp error_response(:limit_exceeded) do
    %{
      description: "Usage limit exceeded for the current plan",
      content: json_content(schema_ref("LimitExceededResponse"))
    }
  end

  defp error_response(:not_found) do
    %{
      description: "Requested resource was not found",
      content: json_content(schema_ref("ErrorEnvelope"))
    }
  end

  defp error_response(:validation) do
    %{
      description: "Validation failed",
      content: json_content(schema_ref("ValidationErrorEnvelope"))
    }
  end

  defp error_response(:unprocessable) do
    %{
      description: "Request could not be completed in the current resource state",
      content: json_content(schema_ref("ErrorEnvelope"))
    }
  end

  defp maybe_put_security(operation, %{public?: true}), do: operation

  defp maybe_put_security(operation, _metadata) do
    Map.put(operation, :security, [%{"BearerAuth" => []}])
  end

  defp maybe_put_request_body(operation, %{request_body: request_body}) do
    schema = %{
      type: "object",
      additionalProperties: true
    }

    Map.put(operation, :requestBody, %{
      required: Map.get(request_body, :required, false),
      description: request_body.description,
      content: %{
        "application/json" => %{
          schema: schema,
          example: request_body.example
        }
      }
    })
  end

  defp maybe_put_request_body(operation, _metadata), do: operation

  defp path_parameter(name, metadata) do
    description =
      metadata
      |> Map.get(:path_parameters, %{})
      |> Map.get(name, default_path_parameter_description(name))

    schema =
      case name do
        "kind" -> %{type: "string", enum: ["logo", "header"]}
        _other -> %{type: "string"}
      end

    %{
      name: name,
      in: "path",
      required: true,
      description: description,
      schema: schema
    }
  end

  defp default_path_parameter_description("id"), do: "Primary resource identifier."
  defp default_path_parameter_description("image_id"), do: "Product image identifier."
  defp default_path_parameter_description("page_id"), do: "Storefront page identifier."
  defp default_path_parameter_description(name), do: "#{String.replace(name, "_", " ")} value."

  defp openapi_path_for(path) do
    Regex.replace(~r/:([A-Za-z0-9_]+)/, path, "{\\1}")
  end

  defp extract_path_params(path) do
    Regex.scan(~r/:([A-Za-z0-9_]+)/, path, capture: :all_but_first)
    |> List.flatten()
  end

  defp operation_id(route) do
    suffix =
      route.path
      |> String.split("/", trim: true)
      |> Enum.map(fn
        ":" <> param -> "By#{Macro.camelize(param)}"
        segment -> Macro.camelize(segment)
      end)
      |> Enum.join()

    "#{String.downcase(route_method(route))}#{suffix}"
  end

  defp route_method(route), do: route.verb |> Atom.to_string() |> String.upcase()

  defp metadata_for(route) do
    Map.get(
      @operation_metadata,
      {route.plug, route.plug_opts},
      default_metadata(route)
    )
  end

  defp default_metadata(route) do
    resource =
      route.plug
      |> Module.split()
      |> List.last()
      |> String.replace_suffix("Controller", "")

    action =
      route.plug_opts
      |> Atom.to_string()
      |> String.replace("_", " ")
      |> String.capitalize()

    %{
      summary: "#{action} #{resource}",
      description: "Undocumented API operation for #{resource}.#{route.plug_opts}.",
      tags: [resource]
    }
  end

  defp default_success_status(%{verb: :post, plug_opts: :create_page}), do: "201"
  defp default_success_status(%{verb: :post, plug_opts: :create}), do: "201"
  defp default_success_status(_route), do: "200"

  defp success_description("201"), do: "Created"
  defp success_description("202"), do: "Accepted"
  defp success_description(_status), do: "Successful response"

  defp json_content(schema) do
    %{
      "application/json" => %{
        schema: schema
      }
    }
  end

  defp schema_ref(name), do: %{"$ref" => "#/components/schemas/#{name}"}

  defp components do
    %{
      securitySchemes: %{
        BearerAuth: %{
          type: "http",
          scheme: "bearer",
          bearerFormat: "token"
        }
      },
      schemas: %{
        SuccessEnvelope: %{
          type: "object",
          required: ["data"],
          properties: %{
            data: %{
              type: "object",
              additionalProperties: true
            }
          }
        },
        ErrorEnvelope: %{
          type: "object",
          required: ["error"],
          properties: %{
            error: %{
              type: "object",
              required: ["code", "detail", "status"],
              properties: %{
                code: %{type: "string"},
                detail: %{type: "string"},
                status: %{type: "integer"}
              },
              additionalProperties: true
            }
          }
        },
        ValidationErrorEnvelope: %{
          type: "object",
          required: ["error"],
          properties: %{
            error: %{
              type: "object",
              required: ["code", "detail", "status", "fields"],
              properties: %{
                code: %{type: "string", const: "validation_failed"},
                detail: %{type: "string"},
                status: %{type: "integer", const: 422},
                fields: %{
                  type: "object",
                  additionalProperties: %{
                    type: "array",
                    items: %{type: "string"}
                  }
                }
              },
              additionalProperties: true
            }
          }
        },
        LimitExceededResponse: %{
          type: "object",
          required: ["error", "operation", "used", "limit", "upgrade_url"],
          properties: %{
            error: %{type: "string", const: "limit_exceeded"},
            operation: %{type: "string"},
            used: %{type: "integer"},
            limit: %{type: "integer"},
            upgrade_url: %{type: "string"}
          }
        }
      }
    }
  end

  defp api_version, do: "v1"
end
