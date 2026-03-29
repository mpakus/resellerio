defmodule Reseller.Media do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Reseller.Catalog.Product
  alias Reseller.Media.FinalizeUploadBatch
  alias Reseller.Media.ProductImage
  alias Reseller.Media.Storage
  alias Reseller.Media.UploadBatch
  alias Reseller.Repo

  @processable_image_statuses ~w(uploaded processing ready)

  @spec prepare_product_uploads(module(), Product.t(), [map()], keyword()) ::
          {:ok, %{images: [ProductImage.t()], upload_instructions: [map()]}}
          | {:error, Ecto.Changeset.t() | term()}
  def prepare_product_uploads(repo \\ Repo, product, uploads, opts \\ [])

  def prepare_product_uploads(_repo, %Product{}, [], _opts) do
    {:ok, %{images: [], upload_instructions: []}}
  end

  def prepare_product_uploads(repo, %Product{} = product, uploads, opts) when is_list(uploads) do
    case validate_uploads(uploads) do
      {:ok, upload_specs} ->
        upload_multi(product, upload_specs, opts)
        |> repo.transaction()
        |> case do
          {:ok, %{upload_bundle: upload_bundle}} -> {:ok, upload_bundle}
          {:error, _step, reason, _changes} -> {:error, reason}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec build_storage_key(Product.t(), ProductImage.t() | map()) :: String.t()
  def build_storage_key(%Product{} = product, upload_spec) do
    extension =
      upload_spec
      |> upload_filename()
      |> Path.extname()

    segment =
      if extension == "" do
        Ecto.UUID.generate()
      else
        Ecto.UUID.generate() <> extension
      end

    "users/#{product.user_id}/products/#{product.id}/originals/#{segment}"
  end

  @spec finalize_product_uploads(module(), Product.t(), [map()]) ::
          {:ok, %{product: Product.t(), finalized_images: [ProductImage.t()]}}
          | {:error, Ecto.Changeset.t() | term()}
  def finalize_product_uploads(repo \\ Repo, %Product{} = product, uploads)
      when is_list(uploads) do
    with {:ok, upload_specs} <- validate_finalize_uploads(uploads),
         {:ok, product} <- preload_product_images(repo, product),
         :ok <- ensure_product_has_images(product),
         :ok <- ensure_images_belong_to_product(product, upload_specs) do
      finalize_upload_multi(product, upload_specs)
      |> repo.transaction()
      |> case do
        {:ok, %{product: finalized_product, finalized_images: finalized_images}} ->
          {:ok, %{product: finalized_product, finalized_images: finalized_images}}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @spec recognition_inputs_for_product(Product.t(), keyword()) ::
          {:ok, [map()]} | {:error, term()}
  def recognition_inputs_for_product(%Product{} = product, opts \\ []) do
    images =
      product.images
      |> List.wrap()
      |> Enum.filter(&(&1.processing_status in @processable_image_statuses))

    if images == [] do
      {:error, :no_recognition_images}
    else
      with {:ok, base_url} <- public_base_url(opts) do
        {:ok, Enum.map(images, &recognition_input(&1, base_url))}
      end
    end
  end

  @spec mark_product_images_ready(Product.t()) :: {:ok, non_neg_integer()}
  def mark_product_images_ready(%Product{id: product_id}) do
    {count, _rows} =
      ProductImage
      |> where(
        [image],
        image.product_id == ^product_id and image.processing_status == "processing"
      )
      |> Repo.update_all(set: [processing_status: "ready"])

    {:ok, count}
  end

  @spec mark_product_images_failed(Product.t()) :: {:ok, non_neg_integer()}
  def mark_product_images_failed(%Product{id: product_id}) do
    {count, _rows} =
      ProductImage
      |> where(
        [image],
        image.product_id == ^product_id and image.processing_status == "processing"
      )
      |> Repo.update_all(set: [processing_status: "failed"])

    {:ok, count}
  end

  defp upload_multi(product, upload_specs, opts) do
    Multi.new()
    |> Multi.run(:upload_bundle, fn repo, _changes ->
      upload_specs
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, %{images: [], upload_instructions: []}}, fn {upload_spec, index},
                                                                             {:ok, acc} ->
        attrs = product_image_attrs(product, upload_spec, index)

        with {:ok, image} <- insert_product_image(repo, product, attrs),
             {:ok, instruction} <- sign_upload(image, opts) do
          {:cont,
           {:ok,
            %{
              images: acc.images ++ [image],
              upload_instructions:
                acc.upload_instructions ++
                  [
                    Map.merge(
                      %{"image_id" => image.id, "storage_key" => image.storage_key},
                      instruction
                    )
                  ]
            }}}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end)
  end

  defp insert_product_image(repo, product, attrs) do
    %ProductImage{}
    |> ProductImage.create_changeset(attrs)
    |> Ecto.Changeset.put_assoc(:product, product)
    |> repo.insert()
  end

  defp sign_upload(%ProductImage{} = image, opts) do
    Storage.sign_upload(
      image.storage_key,
      Keyword.merge(
        [
          content_type: image.content_type,
          provider: Keyword.get(opts, :storage, Storage.provider())
        ],
        Keyword.take(opts, [:expires_in, :request_time, :config])
      )
    )
  end

  defp validate_uploads(uploads) do
    changeset =
      %UploadBatch{}
      |> UploadBatch.changeset(%{"uploads" => uploads})

    if changeset.valid? do
      {:ok, Ecto.Changeset.get_field(changeset, :uploads)}
    else
      {:error, changeset}
    end
  end

  defp product_image_attrs(product, upload_spec, index) do
    position = upload_spec.position || index

    %{
      kind: "original",
      position: position,
      storage_key: build_storage_key(product, upload_spec),
      content_type: upload_spec.content_type,
      byte_size: upload_spec.byte_size,
      checksum: upload_spec.checksum,
      width: upload_spec.width,
      height: upload_spec.height,
      original_filename: upload_spec.filename,
      processing_status: "pending_upload"
    }
  end

  defp upload_filename(upload_spec), do: upload_spec.filename || "upload"

  defp validate_finalize_uploads(uploads) do
    changeset =
      %FinalizeUploadBatch{}
      |> FinalizeUploadBatch.changeset(%{"uploads" => uploads})

    if changeset.valid? do
      {:ok, Ecto.Changeset.get_field(changeset, :uploads)}
    else
      {:error, changeset}
    end
  end

  defp ensure_product_has_images(%Product{images: images}) when is_list(images) and images != [],
    do: :ok

  defp ensure_product_has_images(%Product{}), do: {:error, :no_product_images}

  defp preload_product_images(repo, %Product{} = product) do
    {:ok,
     repo.preload(product,
       images: from(image in ProductImage, order_by: [asc: image.position, asc: image.id])
     )}
  end

  defp ensure_images_belong_to_product(%Product{} = product, upload_specs) do
    valid_ids = MapSet.new(Enum.map(product.images, & &1.id))
    requested_ids = Enum.map(upload_specs, & &1.id)

    if Enum.all?(requested_ids, &MapSet.member?(valid_ids, &1)) do
      :ok
    else
      {:error, :invalid_product_images}
    end
  end

  defp finalize_upload_multi(product, upload_specs) do
    updates_by_id = Map.new(upload_specs, &{&1.id, &1})
    next_status = next_product_status(product.images, upload_specs)

    Multi.new()
    |> Multi.run(:finalized_images, fn repo, _changes ->
      product.images
      |> Enum.filter(&Map.has_key?(updates_by_id, &1.id))
      |> Enum.reduce_while({:ok, []}, fn image, {:ok, finalized_images} ->
        upload_spec = Map.fetch!(updates_by_id, image.id)

        case update_product_image(repo, image, finalized_image_attrs(image, upload_spec)) do
          {:ok, finalized_image} -> {:cont, {:ok, finalized_images ++ [finalized_image]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end)
    |> Multi.run(:product, fn repo, %{finalized_images: _finalized_images} ->
      product
      |> Product.update_changeset(%{"status" => next_status})
      |> repo.update()
      |> case do
        {:ok, updated_product} ->
          {:ok,
           repo.preload(
             updated_product,
             [
               images: from(image in ProductImage, order_by: [asc: image.position, asc: image.id])
             ],
             force: true
           )}

        {:error, changeset} ->
          {:error, changeset}
      end
    end)
  end

  defp update_product_image(repo, image, attrs) do
    image
    |> ProductImage.create_changeset(attrs)
    |> repo.update()
  end

  defp finalized_image_attrs(image, upload_spec) do
    %{
      kind: image.kind,
      position: image.position,
      storage_key: image.storage_key,
      content_type: image.content_type,
      byte_size: upload_spec.byte_size || image.byte_size,
      checksum: upload_spec.checksum || image.checksum,
      width: upload_spec.width || image.width,
      height: upload_spec.height || image.height,
      original_filename: image.original_filename,
      processing_status: "uploaded"
    }
  end

  defp next_product_status(images, upload_specs) do
    updated_ids = MapSet.new(Enum.map(upload_specs, & &1.id))

    if Enum.all?(images, fn image ->
         image.processing_status in ["uploaded", "processing", "ready"] or
           MapSet.member?(updated_ids, image.id)
       end) do
      "processing"
    else
      "uploading"
    end
  end

  defp recognition_input(%ProductImage{} = image, base_url) do
    public_url = build_public_url(base_url, image.storage_key)

    %{
      kind: image.kind,
      position: image.position,
      mime_type: image.content_type,
      uri: public_url,
      external_url: public_url,
      storage_key: image.storage_key
    }
  end

  defp public_base_url(opts) do
    case configured_public_base_url(opts) do
      nil ->
        {:error, :missing_public_base_url}

      base_url when is_binary(base_url) ->
        case URI.parse(base_url) do
          %URI{scheme: scheme, host: host} when is_binary(scheme) and is_binary(host) ->
            {:ok, base_url}

          _ ->
            {:error, :invalid_public_base_url}
        end
    end
  end

  defp configured_public_base_url(opts) do
    Keyword.get(opts, :public_base_url) ||
      Application.fetch_env!(:reseller, __MODULE__)[:public_base_url] ||
      Application.fetch_env!(:reseller, Reseller.Media.Storage.Tigris)[:base_url]
  end

  defp build_public_url(base_url, storage_key) do
    base_uri = URI.parse(base_url)

    path =
      [base_uri.path || "/", storage_key]
      |> Enum.join("/")
      |> String.replace(~r{/+}, "/")
      |> encode_path()

    %URI{base_uri | path: path, query: nil}
    |> URI.to_string()
  end

  defp encode_path(path) do
    path
    |> String.split("/", trim: false)
    |> Enum.map_join("/", fn segment ->
      URI.encode(segment, fn char -> URI.char_unreserved?(char) end)
    end)
    |> normalize_path()
  end

  defp normalize_path(""), do: "/"

  defp normalize_path(path) do
    if String.starts_with?(path, "/"), do: path, else: "/" <> path
  end
end
