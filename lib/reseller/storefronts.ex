defmodule Reseller.Storefronts do
  @moduledoc """
  Storefront configuration, content, branding, and inquiry persistence.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Reseller.Accounts.User
  alias Reseller.Catalog.Product
  alias Reseller.Media.Storage
  alias Reseller.Media.ProductImage
  alias Reseller.Repo
  alias Reseller.Slugs
  alias Reseller.Storefronts.Storefront
  alias Reseller.Storefronts.StorefrontAsset
  alias Reseller.Storefronts.StorefrontInquiry
  alias Reseller.Storefronts.StorefrontPage
  alias Reseller.Storefronts.ThemePresets
  alias Reseller.Storefronts.Notifier

  @public_product_statuses ~w(ready)

  @spec get_storefront_for_user(User.t()) :: Storefront.t() | nil
  def get_storefront_for_user(%User{id: user_id}) do
    Storefront
    |> where([storefront], storefront.user_id == ^user_id)
    |> preload(^storefront_preload())
    |> Repo.one()
  end

  @spec get_or_build_storefront_for_user(User.t()) :: Storefront.t()
  def get_or_build_storefront_for_user(%User{} = user) do
    case get_storefront_for_user(user) do
      nil ->
        %Storefront{
          user_id: user.id,
          enabled: false,
          theme_id: ThemePresets.default_id(),
          assets: [],
          pages: []
        }

      storefront ->
        storefront
    end
  end

  @spec get_storefront_by_slug(String.t()) :: Storefront.t() | nil
  def get_storefront_by_slug(slug) when is_binary(slug) do
    case Slugs.slugify(slug, max_length: 80) do
      "" ->
        nil

      normalized_slug ->
        Storefront
        |> where([storefront], storefront.slug == ^normalized_slug and storefront.enabled == true)
        |> preload(^public_storefront_preload())
        |> Repo.one()
    end
  end

  def get_storefront_by_slug(_slug), do: nil

  @spec list_public_products(Storefront.t(), keyword()) :: [Product.t()]
  def list_public_products(%Storefront{} = storefront, opts \\ []) do
    search_query = normalize_public_search_query(Keyword.get(opts, :query))

    storefront
    |> public_product_query()
    |> maybe_filter_public_product_search(search_query)
    |> order_by([product, _image],
      desc: product.storefront_published_at,
      desc: product.updated_at,
      desc: product.id
    )
    |> preload(^public_product_preload())
    |> Repo.all()
  end

  @spec get_public_product(Storefront.t(), term()) :: Product.t() | nil
  def get_public_product(%Storefront{} = storefront, product_ref) do
    case extract_public_product_id(product_ref) do
      nil ->
        nil

      product_id ->
        storefront
        |> public_product_query()
        |> where([product, _image], product.id == ^product_id)
        |> preload(^public_product_preload())
        |> Repo.one()
    end
  end

  @spec get_public_page(Storefront.t(), term()) :: StorefrontPage.t() | nil
  def get_public_page(%Storefront{id: storefront_id}, page_slug) when is_binary(page_slug) do
    case Slugs.slugify(page_slug, max_length: 80) do
      "" ->
        nil

      normalized_slug ->
        StorefrontPage
        |> where(
          [page],
          page.storefront_id == ^storefront_id and
            page.slug == ^normalized_slug and
            page.published == true
        )
        |> Repo.one()
    end
  end

  def get_public_page(_storefront, _page_slug), do: nil

  @spec upsert_storefront_for_user(User.t(), map()) ::
          {:ok, Storefront.t()} | {:error, Ecto.Changeset.t()}
  def upsert_storefront_for_user(%User{} = user, attrs) when is_map(attrs) do
    case storefront_record_for_user(user.id) do
      nil ->
        %Storefront{}
        |> Storefront.create_changeset(attrs)
        |> Ecto.Changeset.put_assoc(:user, user)
        |> Repo.insert()
        |> preload_storefront_result()

      storefront ->
        storefront
        |> Storefront.update_changeset(attrs)
        |> Repo.update()
        |> preload_storefront_result()
    end
  end

  @spec change_storefront(Storefront.t(), map()) :: Ecto.Changeset.t()
  def change_storefront(%Storefront{} = storefront, attrs \\ %{}) do
    Storefront.update_changeset(storefront, attrs)
  end

  @spec list_storefront_pages_for_user(User.t()) :: [StorefrontPage.t()]
  def list_storefront_pages_for_user(%User{id: user_id}) do
    StorefrontPage
    |> join(:inner, [page], storefront in assoc(page, :storefront))
    |> where([page, storefront], storefront.user_id == ^user_id)
    |> order_by([page], asc: page.position, asc: page.id)
    |> Repo.all()
  end

  @spec get_storefront_page_for_user(User.t(), term()) :: StorefrontPage.t() | nil
  def get_storefront_page_for_user(%User{id: user_id}, id) do
    case normalize_id(id) do
      nil ->
        nil

      page_id ->
        StorefrontPage
        |> join(:inner, [page], storefront in assoc(page, :storefront))
        |> where([page, storefront], storefront.user_id == ^user_id and page.id == ^page_id)
        |> Repo.one()
    end
  end

  @spec create_storefront_page_for_user(User.t(), map()) ::
          {:ok, StorefrontPage.t()} | {:error, Ecto.Changeset.t() | :storefront_not_found}
  def create_storefront_page_for_user(%User{} = user, attrs) when is_map(attrs) do
    case storefront_record_for_user(user.id) do
      nil ->
        {:error, :storefront_not_found}

      storefront ->
        next_position = next_page_position(storefront.id)

        %StorefrontPage{}
        |> StorefrontPage.create_changeset(Map.put_new(attrs, "position", next_position))
        |> Ecto.Changeset.put_assoc(:storefront, storefront)
        |> Repo.insert()
    end
  end

  @spec update_storefront_page_for_user(User.t(), term(), map()) ::
          {:ok, StorefrontPage.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_storefront_page_for_user(%User{} = user, page_id, attrs) when is_map(attrs) do
    case get_storefront_page_for_user(user, page_id) do
      nil ->
        {:error, :not_found}

      page ->
        page
        |> StorefrontPage.update_changeset(attrs)
        |> Repo.update()
    end
  end

  @spec delete_storefront_page_for_user(User.t(), term()) ::
          {:ok, StorefrontPage.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def delete_storefront_page_for_user(%User{} = user, page_id) do
    case get_storefront_page_for_user(user, page_id) do
      nil -> {:error, :not_found}
      page -> Repo.delete(page)
    end
  end

  @spec change_storefront_page(StorefrontPage.t(), map()) :: Ecto.Changeset.t()
  def change_storefront_page(%StorefrontPage{} = page, attrs \\ %{}) do
    StorefrontPage.update_changeset(page, attrs)
  end

  @spec move_storefront_page_for_user(User.t(), term(), :up | :down) ::
          {:ok, StorefrontPage.t()} | {:error, :edge | :not_found | Ecto.Changeset.t()}
  def move_storefront_page_for_user(%User{} = user, page_id, direction)
      when direction in [:up, :down] do
    pages = list_storefront_pages_for_user(user)

    case Enum.find_index(pages, &id_matches?(&1, page_id)) do
      nil ->
        {:error, :not_found}

      index ->
        neighbor_index =
          case direction do
            :up -> index - 1
            :down -> index + 1
          end

        if neighbor_index < 0 or neighbor_index >= length(pages) do
          {:error, :edge}
        else
          page = Enum.at(pages, index)
          neighbor = Enum.at(pages, neighbor_index)

          Multi.new()
          |> Multi.update(
            :page,
            StorefrontPage.update_changeset(page, %{"position" => neighbor.position})
          )
          |> Multi.update(
            :neighbor,
            StorefrontPage.update_changeset(neighbor, %{"position" => page.position})
          )
          |> Repo.transaction()
          |> case do
            {:ok, %{page: moved_page}} -> {:ok, moved_page}
            {:error, _step, reason, _changes} -> {:error, reason}
          end
        end
    end
  end

  @spec get_storefront_asset_for_user(User.t(), String.t()) :: StorefrontAsset.t() | nil
  def get_storefront_asset_for_user(%User{id: user_id}, kind) when is_binary(kind) do
    normalized_kind = normalize_asset_kind(kind)

    StorefrontAsset
    |> join(:inner, [asset], storefront in assoc(asset, :storefront))
    |> where(
      [asset, storefront],
      storefront.user_id == ^user_id and asset.kind == ^normalized_kind
    )
    |> Repo.one()
  end

  def get_storefront_asset_for_user(_user, _kind), do: nil

  @spec upsert_storefront_asset_for_user(User.t(), String.t(), map()) ::
          {:ok, StorefrontAsset.t()} | {:error, Ecto.Changeset.t() | :storefront_not_found}
  def upsert_storefront_asset_for_user(%User{} = user, kind, attrs)
      when is_binary(kind) and is_map(attrs) do
    case storefront_record_for_user(user.id) do
      nil ->
        {:error, :storefront_not_found}

      storefront ->
        normalized_kind = normalize_asset_kind(kind)
        asset = Repo.get_by(StorefrontAsset, storefront_id: storefront.id, kind: normalized_kind)
        asset_attrs = Map.put(attrs, "kind", normalized_kind)

        case asset do
          nil ->
            %StorefrontAsset{}
            |> StorefrontAsset.create_changeset(asset_attrs)
            |> Ecto.Changeset.put_assoc(:storefront, storefront)
            |> Repo.insert()

          asset ->
            asset
            |> StorefrontAsset.update_changeset(asset_attrs)
            |> Repo.update()
        end
    end
  end

  @spec upload_storefront_asset_for_user(User.t(), String.t(), map(), binary(), keyword()) ::
          {:ok, StorefrontAsset.t()}
          | {:error, :storefront_not_found | Ecto.Changeset.t() | term()}
  def upload_storefront_asset_for_user(%User{} = user, kind, attrs, body, opts \\ [])
      when is_binary(kind) and is_map(attrs) and is_binary(body) do
    case storefront_record_for_user(user.id) do
      nil ->
        {:error, :storefront_not_found}

      storefront ->
        normalized_kind = normalize_asset_kind(kind)
        original_filename = map_value(attrs, "filename") || map_value(attrs, :filename) || "asset"

        content_type =
          map_value(attrs, "content_type") || map_value(attrs, :content_type) ||
            "application/octet-stream"

        byte_size =
          map_value(attrs, "byte_size") || map_value(attrs, :byte_size) || byte_size(body)

        checksum = map_value(attrs, "checksum") || map_value(attrs, :checksum)
        width = map_value(attrs, "width") || map_value(attrs, :width)
        height = map_value(attrs, "height") || map_value(attrs, :height)

        storage_key =
          build_storefront_asset_storage_key(storefront, normalized_kind, original_filename)

        storage_opts =
          [provider: Keyword.get(opts, :storage, Storage.provider()), content_type: content_type]

        with {:ok, _upload} <- Storage.upload_object(storage_key, body, storage_opts),
             {:ok, asset} <-
               upsert_storefront_asset_for_user(user, normalized_kind, %{
                 "storage_key" => storage_key,
                 "content_type" => content_type,
                 "original_filename" => original_filename,
                 "byte_size" => byte_size,
                 "checksum" => checksum,
                 "width" => width,
                 "height" => height
               }) do
          {:ok, asset}
        end
    end
  end

  @spec delete_storefront_asset_for_user(User.t(), String.t()) ::
          {:ok, StorefrontAsset.t()} | {:error, :not_found}
  def delete_storefront_asset_for_user(%User{} = user, kind) when is_binary(kind) do
    case get_storefront_asset_for_user(user, kind) do
      nil -> {:error, :not_found}
      asset -> Repo.delete(asset)
    end
  end

  @spec change_storefront_asset(StorefrontAsset.t(), map()) :: Ecto.Changeset.t()
  def change_storefront_asset(%StorefrontAsset{} = asset, attrs \\ %{}) do
    StorefrontAsset.update_changeset(asset, attrs)
  end

  @spec create_storefront_inquiry(Storefront.t(), map()) ::
          {:ok, StorefrontInquiry.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :rate_limited}
  def create_storefront_inquiry(%Storefront{} = storefront, attrs) when is_map(attrs) do
    with :ok <- check_inquiry_rate_limits(storefront, attrs) do
      result =
        %StorefrontInquiry{}
        |> StorefrontInquiry.create_changeset(attrs)
        |> Ecto.Changeset.put_assoc(:storefront, storefront)
        |> Repo.insert()

      case result do
        {:ok, inquiry} ->
          owner = Repo.get!(User, storefront.user_id)
          Notifier.deliver_inquiry_received(owner, storefront, inquiry)
          {:ok, inquiry}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @spec change_storefront_inquiry(StorefrontInquiry.t(), map()) :: Ecto.Changeset.t()
  def change_storefront_inquiry(%StorefrontInquiry{} = inquiry, attrs \\ %{}) do
    StorefrontInquiry.update_changeset(inquiry, attrs)
  end

  @spec list_inquiries_for_user(User.t(), keyword()) :: %{
          entries: [StorefrontInquiry.t()],
          total_count: non_neg_integer(),
          total_pages: non_neg_integer(),
          page: pos_integer(),
          page_size: pos_integer()
        }
  def list_inquiries_for_user(%User{id: user_id}, opts \\ []) do
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = Keyword.get(opts, :page_size, 20)
    query = normalize_inquiry_search_query(Keyword.get(opts, :query))
    offset = (page - 1) * page_size

    base =
      StorefrontInquiry
      |> join(:inner, [i], s in assoc(i, :storefront))
      |> where([_i, s], s.user_id == ^user_id)
      |> maybe_filter_inquiry_search(query)

    total_count =
      base
      |> select([i, _s], count(i.id))
      |> Repo.one()

    entries =
      base
      |> order_by([i, _s], desc: i.inserted_at, desc: i.id)
      |> limit(^page_size)
      |> offset(^offset)
      |> preload([:storefront, :product])
      |> Repo.all()

    total_pages = max(ceil(total_count / page_size), 1)

    %{
      entries: entries,
      total_count: total_count,
      total_pages: total_pages,
      page: page,
      page_size: page_size
    }
  end

  @spec delete_inquiry_for_user(User.t(), term()) ::
          {:ok, StorefrontInquiry.t()} | {:error, :not_found}
  def delete_inquiry_for_user(%User{id: user_id}, inquiry_id) do
    case normalize_id(inquiry_id) do
      nil ->
        {:error, :not_found}

      id ->
        result =
          StorefrontInquiry
          |> join(:inner, [i], s in assoc(i, :storefront))
          |> where([i, s], i.id == ^id and s.user_id == ^user_id)
          |> Repo.one()

        case result do
          nil -> {:error, :not_found}
          inquiry -> Repo.delete(inquiry)
        end
    end
  end

  defp storefront_record_for_user(user_id) do
    Storefront
    |> where([storefront], storefront.user_id == ^user_id)
    |> Repo.one()
  end

  defp next_page_position(storefront_id) do
    StorefrontPage
    |> where([page], page.storefront_id == ^storefront_id)
    |> select([page], coalesce(max(page.position), 0) + 1)
    |> Repo.one()
  end

  defp preload_storefront_result({:ok, storefront}) do
    {:ok, Repo.preload(storefront, storefront_preload())}
  end

  defp preload_storefront_result(result), do: result

  defp storefront_preload do
    [
      assets: from(asset in StorefrontAsset, order_by: [asc: asset.kind, asc: asset.id]),
      pages: from(page in StorefrontPage, order_by: [asc: page.position, asc: page.id])
    ]
  end

  defp public_storefront_preload do
    [
      assets: from(asset in StorefrontAsset, order_by: [asc: asset.kind, asc: asset.id]),
      pages:
        from(page in StorefrontPage,
          where: page.published == true,
          order_by: [asc: page.position, asc: page.id]
        )
    ]
  end

  defp public_product_preload do
    [
      :marketplace_listings,
      images: from(image in ProductImage, order_by: [asc: image.position, asc: image.id])
    ]
  end

  defp public_product_query(%Storefront{user_id: user_id}) do
    Product
    |> join(:inner, [product], image in assoc(product, :images))
    |> where(
      [product, image],
      product.user_id == ^user_id and
        product.storefront_enabled == true and
        product.status in ^@public_product_statuses and
        image.kind == "original" and
        image.processing_status != "pending_upload"
    )
    |> distinct([product, _image], product.id)
  end

  defp maybe_filter_public_product_search(query, search_query) when is_binary(search_query) do
    where(
      query,
      [product, _image],
      fragment("search_document @@ websearch_to_tsquery('simple', ?)", ^search_query)
    )
  end

  defp maybe_filter_public_product_search(query, _search_query), do: query

  defp normalize_id(id) when is_integer(id) and id > 0, do: id

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {value, ""} when value > 0 -> value
      _other -> nil
    end
  end

  defp normalize_id(_id), do: nil

  defp extract_public_product_id(id) when is_integer(id) and id > 0, do: id

  defp extract_public_product_id(id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {value, _rest} when value > 0 -> value
      _other -> nil
    end
  end

  defp extract_public_product_id(_id), do: nil

  defp maybe_filter_inquiry_search(query, nil), do: query

  defp maybe_filter_inquiry_search(query, search) when is_binary(search) do
    pattern = "%#{search}%"

    where(
      query,
      [i, _s],
      ilike(i.full_name, ^pattern) or
        ilike(i.contact, ^pattern) or
        ilike(i.message, ^pattern)
    )
  end

  defp normalize_inquiry_search_query(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      v -> v
    end
  end

  defp normalize_inquiry_search_query(_), do: nil

  defp normalize_public_search_query(search_query) when is_binary(search_query) do
    case String.trim(search_query) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_public_search_query(_search_query), do: nil

  defp build_storefront_asset_storage_key(%Storefront{} = storefront, kind, original_filename) do
    extension =
      original_filename
      |> to_string()
      |> Path.extname()

    segment =
      if extension == "" do
        Ecto.UUID.generate()
      else
        Ecto.UUID.generate() <> extension
      end

    "users/#{storefront.user_id}/storefronts/#{storefront.id}/#{kind}/#{segment}"
  end

  defp normalize_asset_kind(kind) do
    kind
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp map_value(map, key), do: Map.get(map, key)

  defp id_matches?(%{id: id}, candidate) when is_integer(candidate), do: id == candidate
  defp id_matches?(%{id: id}, candidate) when is_binary(candidate), do: to_string(id) == candidate
  defp id_matches?(_page, _candidate), do: false

  defp check_inquiry_rate_limits(%Storefront{id: storefront_id}, attrs) do
    cfg = Application.fetch_env!(:reseller, Reseller.Storefronts)
    ip_limit = Keyword.get(cfg, :inquiry_ip_limit, 5)
    storefront_limit = Keyword.get(cfg, :inquiry_storefront_limit, 50)
    window_minutes = Keyword.get(cfg, :inquiry_window_minutes, 60)

    since = DateTime.add(DateTime.utc_now(), -window_minutes * 60, :second)
    requester_ip = Map.get(attrs, "requester_ip") || Map.get(attrs, :requester_ip)

    storefront_count =
      StorefrontInquiry
      |> where([i], i.storefront_id == ^storefront_id and i.inserted_at >= ^since)
      |> select([i], count(i.id))
      |> Repo.one()

    if storefront_count >= storefront_limit do
      {:error, :rate_limited}
    else
      ip_count =
        if is_binary(requester_ip) and requester_ip != "" do
          StorefrontInquiry
          |> where(
            [i],
            i.storefront_id == ^storefront_id and
              i.requester_ip == ^requester_ip and
              i.inserted_at >= ^since
          )
          |> select([i], count(i.id))
          |> Repo.one()
        else
          0
        end

      if ip_count >= ip_limit, do: {:error, :rate_limited}, else: :ok
    end
  end
end
