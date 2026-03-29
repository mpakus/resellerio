defmodule Reseller.Media do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Reseller.Catalog.Product
  alias Reseller.Media.ProductImage
  alias Reseller.Media.Storage
  alias Reseller.Media.UploadBatch
  alias Reseller.Repo

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
end
