defmodule ResellerWeb.StorefrontController do
  use ResellerWeb, :controller

  alias Reseller.Storefronts
  alias ResellerWeb.PageTitle

  def index(conn, %{"slug" => slug} = params) do
    case Storefronts.get_storefront_by_slug(slug) do
      nil ->
        render_global_not_found(conn)

      storefront ->
        query = normalize_query(Map.get(params, "q"))

        render(conn, :index,
          current_user: conn.assigns[:current_user],
          flash: conn.assigns[:flash] || %{},
          page_title: PageTitle.build(storefront.title, "Public Storefront"),
          products: Storefronts.list_public_products(storefront, query: query),
          query: query,
          storefront: storefront
        )
    end
  end

  def show_product(conn, %{"slug" => slug, "product_ref" => product_ref}) do
    case Storefronts.get_storefront_by_slug(slug) do
      nil ->
        render_global_not_found(conn)

      storefront ->
        case Storefronts.get_public_product(storefront, product_ref) do
          nil ->
            render_storefront_not_found(conn, storefront, "product", product_ref)

          product ->
            render(conn, :product,
              current_user: conn.assigns[:current_user],
              flash: conn.assigns[:flash] || %{},
              page_title: PageTitle.build(product.title || storefront.title, storefront.title),
              product: product,
              query: nil,
              storefront: storefront
            )
        end
    end
  end

  def show_page(conn, %{"slug" => slug, "page_slug" => page_slug}) do
    case Storefronts.get_storefront_by_slug(slug) do
      nil ->
        render_global_not_found(conn)

      storefront ->
        case Storefronts.get_public_page(storefront, page_slug) do
          nil ->
            render_storefront_not_found(conn, storefront, "page", page_slug)

          page ->
            render(conn, :page,
              current_user: conn.assigns[:current_user],
              flash: conn.assigns[:flash] || %{},
              page: page,
              page_title: PageTitle.build(page.title, storefront.title),
              query: nil,
              storefront: storefront
            )
        end
    end
  end

  def create_inquiry(conn, %{"slug" => slug, "product_ref" => product_ref} = params) do
    case Storefronts.get_storefront_by_slug(slug) do
      nil ->
        render_global_not_found(conn)

      storefront ->
        case Storefronts.get_public_product(storefront, product_ref) do
          nil ->
            render_storefront_not_found(conn, storefront, "product", product_ref)

          product ->
            inquiry_params = Map.get(params, "inquiry", %{})

            if Map.get(inquiry_params, "website", "") != "" do
              conn
              |> put_flash(:info, "Thank you for your message!")
              |> redirect(to: ~p"/store/#{slug}/products/#{product_ref}")
            else
              requester_ip =
                conn.remote_ip
                |> :inet.ntoa()
                |> to_string()

              attrs =
                inquiry_params
                |> Map.put("product_id", product.id)
                |> Map.put("source_path", "/store/#{slug}/products/#{product_ref}")
                |> Map.put("requester_ip", requester_ip)
                |> Map.put("user_agent", get_req_header(conn, "user-agent") |> List.first(""))

              case Storefronts.create_storefront_inquiry(storefront, attrs) do
                {:ok, _inquiry} ->
                  conn
                  |> put_flash(
                    :info,
                    "Your request has been sent. The seller will be in touch soon."
                  )
                  |> redirect(to: ~p"/store/#{slug}/products/#{product_ref}")

                {:error, :rate_limited} ->
                  conn
                  |> put_flash(:error, "Too many requests. Please try again later.")
                  |> redirect(to: ~p"/store/#{slug}/products/#{product_ref}")

                {:error, changeset} ->
                  errors =
                    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
                      Enum.reduce(opts, msg, fn {key, value}, acc ->
                        String.replace(acc, "%{#{key}}", to_string(value))
                      end)
                    end)
                    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)

                  conn
                  |> put_flash(:error, "Could not submit request: #{Enum.join(errors, "; ")}")
                  |> redirect(to: ~p"/store/#{slug}/products/#{product_ref}")
              end
            end
        end
    end
  end

  defp render_storefront_not_found(conn, storefront, missing_kind, missing_target) do
    conn
    |> put_status(:not_found)
    |> render(:not_found,
      current_user: conn.assigns[:current_user],
      flash: conn.assigns[:flash] || %{},
      missing_kind: missing_kind,
      missing_target: missing_target,
      page_title: PageTitle.build("Not Found", storefront.title),
      query: nil,
      storefront: storefront
    )
  end

  defp render_global_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(html: ResellerWeb.ErrorHTML)
    |> render(:"404")
  end

  defp normalize_query(query) when is_binary(query) do
    case String.trim(query) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_query(_query), do: nil
end
