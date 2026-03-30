defmodule Reseller.Catalog do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Reseller.Accounts.User
  alias Reseller.Catalog.Product
  alias Reseller.Media
  alias Reseller.Repo
  alias Reseller.Workers

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

  def update_product_for_user(%User{} = user, product_id, attrs) when is_map(attrs) do
    case get_product_for_user(user, product_id) do
      nil ->
        {:error, :not_found}

      product ->
        attrs =
          attrs
          |> editable_product_attrs()
          |> apply_manual_status_transition(product)

        product
        |> Product.update_changeset(attrs)
        |> validate_manual_status_change()
        |> Repo.update()
        |> case do
          {:ok, updated_product} -> {:ok, refresh_product(updated_product)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def delete_product_for_user(%User{} = user, product_id) do
    case get_product_for_user(user, product_id) do
      nil ->
        {:error, :not_found}

      product ->
        Repo.delete(product)
    end
  end

  def mark_product_sold_for_user(%User{} = user, product_id, attrs \\ %{}) when is_map(attrs) do
    case get_product_for_user(user, product_id) do
      nil ->
        {:error, :not_found}

      product ->
        sold_at =
          case Map.get(attrs, "sold_at") do
            %DateTime{} = datetime -> datetime
            nil -> DateTime.utc_now() |> DateTime.truncate(:second)
            _other -> DateTime.utc_now() |> DateTime.truncate(:second)
          end

        update_status_for_product(product, %{
          "status" => "sold",
          "sold_at" => sold_at,
          "archived_at" => nil
        })
    end
  end

  def archive_product_for_user(%User{} = user, product_id) do
    case get_product_for_user(user, product_id) do
      nil ->
        {:error, :not_found}

      product ->
        update_status_for_product(product, %{
          "status" => "archived",
          "archived_at" => DateTime.utc_now() |> DateTime.truncate(:second)
        })
    end
  end

  def unarchive_product_for_user(%User{} = user, product_id) do
    case get_product_for_user(user, product_id) do
      nil ->
        {:error, :not_found}

      %Product{status: "archived"} = product ->
        restored_status = if product.sold_at, do: "sold", else: "ready"

        update_status_for_product(product, %{
          "status" => restored_status,
          "archived_at" => nil
        })

      product ->
        update_status_for_product(product, %{
          "status" => if(product.sold_at, do: "sold", else: product.status || "ready"),
          "archived_at" => nil
        })
    end
  end

  def finalize_product_uploads_for_user(%User{} = user, product_id, uploads)
      when is_list(uploads) do
    case get_product_for_user(user, product_id) do
      nil ->
        {:error, :not_found}

      product ->
        with {:ok, %{product: product, finalized_images: finalized_images}} <-
               Media.finalize_product_uploads(Repo, product, uploads),
             {:ok, processing_run} <- maybe_start_processing(product) do
          {:ok,
           %{
             product: refresh_product(product),
             finalized_images: finalized_images,
             processing_run: processing_run
           }}
        end
    end
  end

  def apply_recognition_result(%Product{} = product, result) when is_map(result) do
    product
    |> Product.update_changeset(recognition_result_attrs(product, result))
    |> Repo.update()
    |> case do
      {:ok, updated_product} -> {:ok, refresh_product(updated_product)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def mark_processing_failed(%Product{} = product) do
    product
    |> Product.update_changeset(%{"status" => "review"})
    |> Repo.update()
    |> case do
      {:ok, updated_product} -> {:ok, refresh_product(updated_product)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp product_changeset(%User{} = user, attrs) do
    %Product{}
    |> Product.create_changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
  end

  defp editable_product_attrs(attrs) do
    Map.take(attrs, [
      "status",
      "title",
      "brand",
      "category",
      "condition",
      "color",
      "size",
      "material",
      "price",
      "cost",
      "sku",
      "tags",
      "notes"
    ])
  end

  defp apply_manual_status_transition(attrs, %Product{} = product) do
    case Map.get(attrs, "status") do
      nil ->
        attrs

      status ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        attrs
        |> Map.merge(status_transition_attrs(product, status, now))
    end
  end

  defp status_transition_attrs(%Product{} = product, "sold", now) do
    %{
      "sold_at" => product.sold_at || now,
      "archived_at" => nil
    }
  end

  defp status_transition_attrs(_product, "archived", now) do
    %{
      "archived_at" => now
    }
  end

  defp status_transition_attrs(_product, status, _now) when status in ~w(draft review ready) do
    %{
      "sold_at" => nil,
      "archived_at" => nil
    }
  end

  defp status_transition_attrs(_product, _status, _now), do: %{}

  defp validate_manual_status_change(changeset) do
    case Ecto.Changeset.fetch_change(changeset, :status) do
      {:ok, _status} ->
        Ecto.Changeset.validate_inclusion(changeset, :status, Product.manual_statuses())

      :error ->
        changeset
    end
  end

  defp product_preload do
    [
      :description_draft,
      :price_research,
      :marketplace_listings,
      images:
        from(image in Reseller.Media.ProductImage, order_by: [asc: image.position, asc: image.id]),
      processing_runs:
        from(run in Reseller.Workers.ProductProcessingRun,
          order_by: [desc: run.inserted_at, desc: run.id]
        )
    ]
  end

  defp maybe_start_processing(%Product{status: "processing"} = product) do
    Workers.start_product_processing(product)
  end

  defp maybe_start_processing(_product), do: {:ok, nil}

  defp refresh_product(product), do: Repo.preload(product, product_preload(), force: true)

  defp update_status_for_product(%Product{} = product, attrs) do
    product
    |> Product.update_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_product} -> {:ok, refresh_product(updated_product)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp recognition_result_attrs(%Product{} = product, result) do
    generated_title = generated_title(result)
    generated_summary = generated_summary(result)

    %{
      "status" => if(result["needs_review"], do: "review", else: "ready"),
      "title" => prefer_existing(product.title, generated_title),
      "brand" => prefer_existing(product.brand, result["brand"]),
      "category" => prefer_existing(product.category, result["category"]),
      "color" => prefer_existing(product.color, result["color"]),
      "material" => prefer_existing(product.material, result["material"]),
      "ai_summary" => generated_summary || product.ai_summary,
      "ai_confidence" =>
        normalized_confidence(result["confidence_score"]) || product.ai_confidence
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp generated_title(result) do
    cond do
      present?(result["short_card_description"]) ->
        result["short_card_description"]

      present?(result["brand"]) and present?(result["possible_model"]) ->
        result["brand"] <> " " <> result["possible_model"]

      present?(result["brand"]) and present?(result["category"]) ->
        result["brand"] <> " " <> result["category"]

      true ->
        nil
    end
  end

  defp generated_summary(result) do
    cond do
      present?(result["short_card_description"]) ->
        result["short_card_description"]

      match?([_ | _], result["distinguishing_features"]) ->
        result["distinguishing_features"]
        |> Enum.take(3)
        |> Enum.join(", ")

      present?(result["possible_model"]) and present?(result["category"]) ->
        result["possible_model"] <> " " <> result["category"]

      true ->
        nil
    end
  end

  defp prefer_existing(existing, generated) do
    if present?(existing), do: existing, else: generated
  end

  defp normalized_confidence(value) when is_number(value), do: value * 1.0
  defp normalized_confidence(_value), do: nil

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
