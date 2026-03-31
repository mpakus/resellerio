defmodule Reseller.Media do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Reseller.Catalog.Product
  alias Reseller.Media.FinalizeUploadBatch
  alias Reseller.Media.Processor
  alias Reseller.Media.ProductImage
  alias Reseller.Media.Storage
  alias Reseller.Media.UploadBatch
  alias Reseller.Repo

  @processable_image_statuses ~w(uploaded processing ready)
  @variant_profiles [%{kind: "background_removed", background_style: "transparent"}]
  @lifestyle_input_priority %{
    "background_removed" => 1,
    "white_background" => 2,
    "original" => 3
  }

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
      images
      |> Enum.reduce_while({:ok, []}, fn image, {:ok, inputs} ->
        case recognition_input(image, opts) do
          {:ok, input} -> {:cont, {:ok, inputs ++ [input]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  @spec lifestyle_generation_inputs_for_product(Product.t(), keyword()) ::
          {:ok, %{inputs: [map()], source_images: [ProductImage.t()]}} | {:error, term()}
  def lifestyle_generation_inputs_for_product(%Product{} = product, opts \\ []) do
    source_images =
      product
      |> Repo.preload(:images, force: true)
      |> Map.fetch!(:images)
      |> select_lifestyle_generation_source_images()

    if source_images == [] do
      {:error, :no_lifestyle_images}
    else
      source_images
      |> Enum.reduce_while({:ok, []}, fn image, {:ok, inputs} ->
        case recognition_input(image, opts) do
          {:ok, input} -> {:cont, {:ok, inputs ++ [input]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, inputs} -> {:ok, %{inputs: inputs, source_images: source_images}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @spec public_url_for_image(ProductImage.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def public_url_for_image(%ProductImage{} = image, opts \\ []) do
    with {:ok, base_url} <- public_base_url(opts) do
      {:ok, build_public_url(base_url, image.storage_key)}
    end
  end

  @spec public_url_for_storage_key(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def public_url_for_storage_key(storage_key, opts \\ []) when is_binary(storage_key) do
    with {:ok, base_url} <- public_base_url(opts) do
      {:ok, build_public_url(base_url, storage_key)}
    end
  end

  @spec public_url_for_storage_key!(String.t(), keyword()) :: String.t()
  def public_url_for_storage_key!(storage_key, opts \\ []) when is_binary(storage_key) do
    case public_url_for_storage_key(storage_key, opts) do
      {:ok, url} ->
        url

      {:error, reason} ->
        raise "could not build public url for #{storage_key}: #{inspect(reason)}"
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

  @spec mark_product_images_retryable(Product.t()) :: {:ok, non_neg_integer()}
  def mark_product_images_retryable(%Product{id: product_id}) do
    {count, _rows} =
      ProductImage
      |> where(
        [image],
        image.product_id == ^product_id and image.kind == "original" and
          image.processing_status in ["processing", "failed"]
      )
      |> Repo.update_all(set: [processing_status: "uploaded"])

    {:ok, count}
  end

  @spec create_lifestyle_generated_image(Product.t(), map()) ::
          {:ok, ProductImage.t()} | {:error, Ecto.Changeset.t()}
  def create_lifestyle_generated_image(%Product{} = product, attrs) when is_map(attrs) do
    product = Repo.preload(product, :images, force: true)

    product
    |> lifestyle_generated_image_attrs(attrs)
    |> then(fn image_attrs ->
      %ProductImage{}
      |> ProductImage.create_changeset(image_attrs)
      |> Ecto.Changeset.put_assoc(:product, product)
      |> Repo.insert()
    end)
  end

  @spec get_lifestyle_generated_image(Product.t(), pos_integer()) :: ProductImage.t() | nil
  def get_lifestyle_generated_image(%Product{id: product_id}, image_id)
      when is_integer(image_id) do
    ProductImage
    |> where(
      [image],
      image.product_id == ^product_id and image.id == ^image_id and
        image.kind == "lifestyle_generated"
    )
    |> Repo.one()
  end

  @spec approve_lifestyle_generated_image(Product.t(), pos_integer()) ::
          {:ok, ProductImage.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def approve_lifestyle_generated_image(%Product{} = product, image_id)
      when is_integer(image_id) do
    case get_lifestyle_generated_image(product, image_id) do
      nil ->
        {:error, :not_found}

      image ->
        image
        |> ProductImage.create_changeset(%{
          "seller_approved" => true,
          "approved_at" => DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()
    end
  end

  @spec delete_lifestyle_generated_image(Product.t(), pos_integer()) ::
          {:ok, ProductImage.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete_lifestyle_generated_image(%Product{} = product, image_id)
      when is_integer(image_id) do
    case get_lifestyle_generated_image(product, image_id) do
      nil -> {:error, :not_found}
      image -> Repo.delete(image)
    end
  end

  @spec delete_product_image(Product.t(), pos_integer()) ::
          {:ok, %{deleted_image_ids: [pos_integer()]}} | {:error, :not_found}
  def delete_product_image(%Product{} = product, image_id) when is_integer(image_id) do
    product = Repo.preload(product, :images, force: true)

    case Enum.find(product.images, &(&1.id == image_id)) do
      nil ->
        {:error, :not_found}

      image ->
        deleted_image_ids = image_ids_for_deletion(product.images, image)

        Multi.new()
        |> Multi.delete_all(
          :deleted_images,
          from(product_image in ProductImage, where: product_image.id in ^deleted_image_ids)
        )
        |> Repo.transaction()
        |> case do
          {:ok, _changes} -> {:ok, %{deleted_image_ids: deleted_image_ids}}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  @spec generate_product_variants(Product.t(), keyword()) ::
          {:ok, [ProductImage.t()]} | {:error, term()}
  def generate_product_variants(%Product{} = product, opts \\ []) do
    product = Repo.preload(product, :images, force: true)

    with {:ok, base_url} <- public_base_url(opts) do
      product.images
      |> Enum.filter(&variant_source_image?/1)
      |> Enum.reduce_while({:ok, []}, fn source_image, {:ok, variants} ->
        case generate_variants_for_image(product, source_image, base_url, opts) do
          {:ok, created_variants} -> {:cont, {:ok, variants ++ created_variants}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
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
    position =
      product
      |> next_product_image_position()
      |> Kernel.+(index - 1)

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

  defp lifestyle_generated_image_attrs(%Product{} = product, attrs) do
    attrs
    |> stringify_keys()
    |> Map.put("kind", "lifestyle_generated")
    |> Map.put_new("position", next_product_image_position(product))
    |> Map.put_new("processing_status", "ready")
    |> Map.put_new("background_style", "lifestyle")
    |> Map.put_new("seller_approved", false)
    |> Map.update("source_image_ids", [], &normalize_image_ids/1)
  end

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

  defp upsert_variant_image(repo, product, source_image, profile, attrs) do
    case find_variant_image(product, profile.kind, source_image.position) do
      nil ->
        %ProductImage{}
        |> ProductImage.create_changeset(attrs)
        |> Ecto.Changeset.put_assoc(:product, product)
        |> repo.insert()

      variant_image ->
        variant_image
        |> ProductImage.create_changeset(attrs)
        |> repo.update()
    end
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

  defp recognition_input(%ProductImage{} = image, opts) do
    with {:ok, fetch_url} <- external_fetch_url(image, opts) do
      {:ok,
       %{
         kind: image.kind,
         position: image.position,
         mime_type: image.content_type,
         uri: fetch_url,
         external_url: fetch_url,
         storage_key: image.storage_key
       }}
    end
  end

  defp generate_variants_for_image(product, source_image, _base_url, opts) do
    @variant_profiles
    |> Enum.reduce_while({:ok, []}, fn profile, {:ok, variants} ->
      storage_key = build_variant_storage_key(product, source_image, profile)

      with {:ok, image_url} <- external_fetch_url(source_image, opts),
           {:ok, processed_image} <- process_variant(image_url, profile, opts),
           {:ok, _upload} <-
             Storage.upload_object(
               storage_key,
               processed_image.body,
               Keyword.merge(
                 [
                   content_type: processed_image.content_type,
                   provider: Keyword.get(opts, :storage, Storage.provider())
                 ],
                 Keyword.take(opts, [:upload_request_fun, :request_time, :expires_in, :config])
               )
             ),
           {:ok, variant} <-
             upsert_variant_image(
               Repo,
               product,
               source_image,
               profile,
               variant_image_attrs(source_image, profile, processed_image, storage_key)
             ) do
        {:cont, {:ok, variants ++ [variant]}}
      else
        {:error, reason} -> {:halt, {:error, {:variant_generation_failed, profile.kind, reason}}}
      end
    end)
  end

  defp process_variant(image_url, profile, opts) do
    Processor.process_image(
      image_url,
      profile,
      opts
      |> Keyword.put_new(:provider, Keyword.get(opts, :media_processor, Processor.provider()))
    )
  end

  defp variant_image_attrs(source_image, profile, processed_image, storage_key) do
    %{
      kind: profile.kind,
      position: source_image.position,
      storage_key: storage_key,
      content_type: processed_image.content_type,
      byte_size: processed_image.byte_size,
      checksum: source_image.checksum,
      width: Map.get(processed_image, :width) || source_image.width,
      height: Map.get(processed_image, :height) || source_image.height,
      original_filename: source_image.original_filename,
      background_style: profile.background_style,
      processing_status: "ready"
    }
  end

  defp build_variant_storage_key(%Product{} = product, %ProductImage{} = source_image, profile) do
    "users/#{product.user_id}/products/#{product.id}/variants/#{source_image.id}-#{profile.kind}.png"
  end

  defp find_variant_image(%Product{} = product, kind, position) do
    Enum.find(product.images || [], &(&1.kind == kind and &1.position == position))
  end

  defp image_ids_for_deletion(images, %ProductImage{kind: "original"} = image) do
    variant_image_ids =
      images
      |> Enum.filter(
        &(&1.position == image.position and &1.kind in ~w(background_removed white_background))
      )
      |> Enum.map(& &1.id)

    dependent_preview_ids =
      images
      |> Enum.filter(
        &(&1.kind == "lifestyle_generated" and image.id in List.wrap(&1.source_image_ids))
      )
      |> Enum.map(& &1.id)

    ([image.id] ++ variant_image_ids ++ dependent_preview_ids)
    |> Enum.uniq()
  end

  defp image_ids_for_deletion(_images, %ProductImage{} = image), do: [image.id]

  defp select_lifestyle_generation_source_images(images) do
    images
    |> Enum.filter(&lifestyle_generation_source_image?/1)
    |> Enum.sort_by(fn image ->
      {
        Map.get(@lifestyle_input_priority, image.kind, 99),
        image.position || 0,
        image.id || 0
      }
    end)
    |> Enum.reduce({[], MapSet.new()}, fn image, {selected, seen_kinds} ->
      if MapSet.member?(seen_kinds, image.kind) do
        {selected, seen_kinds}
      else
        {[image | selected], MapSet.put(seen_kinds, image.kind)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.take(3)
  end

  defp lifestyle_generation_source_image?(%ProductImage{} = image) do
    image.kind in Map.keys(@lifestyle_input_priority) and
      image.processing_status in @processable_image_statuses
  end

  defp next_product_image_position(%Product{} = product) do
    images =
      case product.images do
        images when is_list(images) -> images
        _other -> []
      end

    images
    |> Enum.map(&(&1.position || 0))
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp variant_source_image?(%ProductImage{} = image) do
    image.kind == "original" and image.processing_status in @processable_image_statuses
  end

  defp external_fetch_url(%ProductImage{} = image, opts) do
    case Storage.sign_download(
           image.storage_key,
           Keyword.put_new(opts, :provider, Keyword.get(opts, :storage, Storage.provider()))
         ) do
      {:ok, %{download_url: download_url}} when is_binary(download_url) ->
        {:ok, download_url}

      {:ok, %{"download_url" => download_url}} when is_binary(download_url) ->
        {:ok, download_url}

      {:error, _reason} ->
        public_url_for_image(image, opts)
    end
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
      case Keyword.get(opts, :config) do
        nil ->
          nil

        config ->
          case Reseller.Media.Storage.Tigris.public_base_url(config) do
            {:ok, base_url} -> base_url
            {:error, _reason} -> nil
          end
      end ||
      Application.fetch_env!(:reseller, __MODULE__)[:public_base_url] ||
      case Reseller.Media.Storage.Tigris.public_base_url(
             Keyword.get(
               opts,
               :config,
               Application.fetch_env!(:reseller, Reseller.Media.Storage.Tigris)
             )
           ) do
        {:ok, base_url} -> base_url
        {:error, _reason} -> nil
      end
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

  defp normalize_image_ids(nil), do: []

  defp normalize_image_ids(image_ids) when is_list(image_ids) do
    image_ids
    |> Enum.map(fn
      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {integer, ""} -> integer
          _other -> value
        end

      value ->
        value
    end)
    |> Enum.filter(&is_integer/1)
    |> Enum.uniq()
  end

  defp normalize_image_ids(_image_ids), do: []

  defp stringify_keys(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
