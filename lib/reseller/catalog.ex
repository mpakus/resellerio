defmodule Reseller.Catalog do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Reseller.Accounts.User
  alias Reseller.Catalog.Product
  alias Reseller.Media
  alias Reseller.Repo

  def list_products_for_user(%User{id: user_id}) do
    Product
    |> where([product], product.user_id == ^user_id)
    |> order_by([product], desc: product.inserted_at)
    |> preload(^product_preload())
    |> Repo.all()
  end

  def get_product_for_user(%User{id: user_id}, id) do
    Product
    |> where([product], product.user_id == ^user_id and product.id == ^id)
    |> preload(^product_preload())
    |> Repo.one()
  end

  def create_product_for_user(%User{} = user, attrs \\ %{}, uploads \\ [], opts \\ [])
      when is_map(attrs) and is_list(uploads) do
    initial_status = if uploads == [], do: "draft", else: "uploading"

    Multi.new()
    |> Multi.insert(
      :product,
      product_changeset(user, Map.put_new(attrs, "status", initial_status))
    )
    |> Multi.run(:upload_bundle, fn repo, %{product: product} ->
      Media.prepare_product_uploads(repo, product, uploads, opts)
    end)
    |> Multi.run(:product_with_images, fn repo, %{product: product} ->
      {:ok, repo.preload(product, product_preload())}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{product_with_images: product, upload_bundle: upload_bundle}} ->
        {:ok, %{product: product, upload_bundle: upload_bundle}}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  def finalize_product_uploads_for_user(%User{} = user, product_id, uploads)
      when is_list(uploads) do
    case get_product_for_user(user, product_id) do
      nil ->
        {:error, :not_found}

      product ->
        Media.finalize_product_uploads(Repo, product, uploads)
    end
  end

  defp product_changeset(%User{} = user, attrs) do
    %Product{}
    |> Product.create_changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
  end

  defp product_preload do
    [
      images:
        from(image in Reseller.Media.ProductImage, order_by: [asc: image.position, asc: image.id])
    ]
  end
end
