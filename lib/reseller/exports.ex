defmodule Reseller.Exports do
  @moduledoc """
  Handles export record lifecycle, filtered archive generation, and notifications.
  """

  import Ecto.Query, warn: false

  alias Reseller.Accounts.User
  alias Reseller.Catalog
  alias Reseller.Exports.Export
  alias Reseller.Exports.ExportWorker
  alias Reseller.Media
  alias Reseller.Media.Storage
  alias Reseller.Repo

  @topic_prefix "exports"
  @allowed_statuses ~w(all draft uploading processing review ready sold archived)
  @allowed_sorts ~w(title status price updated_at inserted_at)
  @allowed_sort_dirs ~w(asc desc)
  @max_error_message_length 500
  @legacy_db_error_message_length 255

  @spec subscribe(User.t()) :: :ok | {:error, term()}
  def subscribe(%User{id: user_id}) do
    Phoenix.PubSub.subscribe(Reseller.PubSub, topic(user_id))
  end

  @spec request_export_for_user(User.t(), keyword()) ::
          {:ok, Export.t()} | {:error, Ecto.Changeset.t() | term()}
  def request_export_for_user(%User{} = user, opts \\ []) do
    requested_at = now(Keyword.get(opts, :requested_at))
    filter_params = normalize_filter_params(Keyword.get(opts, :filters, %{}))

    product_count =
      Catalog.count_filtered_products_for_user(user, filter_params_to_catalog_opts(filter_params))

    if product_count < 1 do
      {:error, :no_products}
    else
      name = normalize_export_name(Keyword.get(opts, :name), requested_at)

      attrs = %{
        "name" => name,
        "file_name" => build_file_name(name, requested_at),
        "filter_params" => filter_params,
        "product_count" => product_count,
        "status" => "queued",
        "requested_at" => requested_at
      }

      with {:ok, export} <- create_export(user, attrs),
           :ok <- enqueue_export(export, opts) do
        {:ok, get_export!(export.id)}
      end
    end
  end

  @spec get_export(pos_integer()) :: Export.t() | nil
  def get_export(id) when is_integer(id), do: Repo.get(Export, id)

  @spec get_export!(pos_integer()) :: Export.t()
  def get_export!(id) when is_integer(id), do: Repo.get!(Export, id)

  @spec get_export_for_user(User.t(), term()) :: Export.t() | nil
  def get_export_for_user(%User{id: user_id}, id) do
    Export
    |> where([export], export.user_id == ^user_id and export.id == ^id)
    |> Repo.one()
  end

  @spec list_exports_for_user(User.t()) :: [Export.t()]
  def list_exports_for_user(%User{id: user_id}) do
    Export
    |> where([export], export.user_id == ^user_id)
    |> order_by([export], desc: export.requested_at, desc: export.id)
    |> Repo.all()
  end

  @spec mark_running(Export.t()) :: Export.t()
  def mark_running(%Export{} = export) do
    export
    |> Export.update_changeset(%{
      "status" => "running",
      "error_message" => nil
    })
    |> Repo.update!()
    |> broadcast_export_update()
  end

  @spec mark_completed(Export.t(), String.t(), keyword()) ::
          {:ok, Export.t()} | {:error, Ecto.Changeset.t()}
  def mark_completed(%Export{} = export, storage_key, opts \\ []) do
    ttl_days =
      Keyword.get(
        opts,
        :ttl_days,
        Application.fetch_env!(:reseller, __MODULE__)[:export_ttl_days]
      )

    expires_at =
      now()
      |> DateTime.add(ttl_days * 86_400, :second)
      |> DateTime.truncate(:second)

    export
    |> Export.update_changeset(%{
      "status" => "completed",
      "storage_key" => storage_key,
      "expires_at" => expires_at,
      "completed_at" => now(),
      "error_message" => nil
    })
    |> Repo.update()
    |> broadcast_update_result()
  end

  @spec mark_failed(Export.t(), String.t()) :: {:ok, Export.t()} | {:error, Ecto.Changeset.t()}
  def mark_failed(%Export{} = export, error_message) do
    persist_failed_export(
      export,
      normalize_error_message(error_message, @max_error_message_length)
    )
  end

  @spec export_user!(Export.t()) :: User.t()
  def export_user!(%Export{user_id: user_id}), do: Repo.get!(User, user_id)

  @spec build_storage_key(Export.t(), User.t()) :: String.t()
  def build_storage_key(%Export{id: export_id, file_name: file_name}, %User{id: user_id}) do
    "users/#{user_id}/exports/#{export_id}/#{file_name}"
  end

  @spec processing_mode(keyword()) :: :async | :inline
  def processing_mode(opts \\ []) do
    Keyword.get(opts, :mode, Application.fetch_env!(:reseller, __MODULE__)[:processing_mode])
  end

  @spec filter_params_to_catalog_opts(map()) :: keyword()
  def filter_params_to_catalog_opts(filter_params) when is_map(filter_params) do
    [
      status: Map.get(filter_params, "status"),
      query: Map.get(filter_params, "query"),
      updated_from: parse_date(Map.get(filter_params, "updated_from")),
      updated_to: parse_date(Map.get(filter_params, "updated_to")),
      sort: Map.get(filter_params, "sort"),
      sort_dir: Map.get(filter_params, "dir")
    ]
  end

  @spec normalize_filter_params(map() | keyword() | nil) :: map()
  def normalize_filter_params(filters) when is_list(filters) do
    filters
    |> Enum.into(%{})
    |> normalize_filter_params()
  end

  def normalize_filter_params(filters) when is_map(filters) do
    status = normalize_filter_status(filter_value(filters, "status"))
    query = normalize_filter_query(filter_value(filters, "query"))
    updated_from = normalize_filter_date(filter_value(filters, "updated_from"))
    updated_to = normalize_filter_date(filter_value(filters, "updated_to"))
    sort = normalize_filter_sort(filter_value(filters, "sort"))
    dir = normalize_filter_sort_dir(filter_value(filters, "dir"))

    %{}
    |> maybe_put_filter("status", status != "all" && status)
    |> maybe_put_filter("query", query)
    |> maybe_put_filter("updated_from", updated_from)
    |> maybe_put_filter("updated_to", updated_to)
    |> maybe_put_filter("sort", sort != "updated_at" && sort)
    |> maybe_put_filter("dir", dir != "desc" && dir)
  end

  def normalize_filter_params(_filters), do: %{}

  @spec filter_details(map()) :: [%{label: String.t(), value: String.t()}]
  def filter_details(filter_params) when is_map(filter_params) do
    []
    |> maybe_add_detail("Search", Map.get(filter_params, "query"))
    |> maybe_add_detail("Status", Map.get(filter_params, "status"))
    |> maybe_add_detail("Updated from", Map.get(filter_params, "updated_from"))
    |> maybe_add_detail("Updated to", Map.get(filter_params, "updated_to"))
    |> maybe_add_detail("Sort", sort_label(filter_params))
  end

  @spec filter_summary(map()) :: String.t()
  def filter_summary(filter_params) when is_map(filter_params) do
    filter_params
    |> filter_details()
    |> Enum.map_join(" · ", fn %{label: label, value: value} -> "#{label}: #{value}" end)
    |> case do
      "" -> "All products"
      summary -> summary
    end
  end

  @spec download_details(Export.t(), keyword()) ::
          {:ok, %{download_url: String.t(), link_expires_at: DateTime.t() | nil}}
          | {:error, term()}
  def download_details(export, opts \\ [])
  def download_details(%Export{storage_key: nil}, _opts), do: {:error, :export_not_ready}

  def download_details(%Export{} = export, opts) do
    storage_opts =
      [
        provider: Keyword.get(opts, :storage, Storage.provider())
      ] ++
        Keyword.take(opts, [
          :request_time,
          :expires_in,
          :config,
          :sign_download_result,
          :public_base_url
        ])

    case Storage.sign_download(export.storage_key, storage_opts) do
      {:ok, payload} ->
        case normalize_download_payload(payload) do
          {:ok, details} -> {:ok, details}
          {:error, _reason} -> fallback_download_details(export, opts)
        end

      {:error, _reason} ->
        fallback_download_details(export, opts)
    end
  end

  @spec download_url(Export.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def download_url(%Export{} = export, opts \\ []) do
    case download_details(export, opts) do
      {:ok, %{download_url: download_url}} -> {:ok, download_url}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_export(%User{} = user, attrs) do
    %Export{}
    |> Export.create_changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
    |> broadcast_insert_result()
  end

  defp enqueue_export(%Export{} = export, opts) do
    case processing_mode(opts) do
      :inline ->
        ExportWorker.perform(export.id, opts)
        :ok

      :async ->
        case Task.Supervisor.start_child(Reseller.Workers.TaskSupervisor, fn ->
               ExportWorker.perform(export.id, opts)
             end) do
          {:ok, _pid} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp broadcast_insert_result({:ok, export}) do
    {:ok, broadcast_export_update(export)}
  end

  defp broadcast_insert_result(error), do: error

  defp broadcast_update_result({:ok, export}) do
    {:ok, broadcast_export_update(export)}
  end

  defp broadcast_update_result(error), do: error

  defp broadcast_export_update(%Export{} = export) do
    Phoenix.PubSub.broadcast(
      Reseller.PubSub,
      topic(export.user_id),
      {:export_updated, export}
    )

    export
  end

  defp topic(user_id), do: "#{@topic_prefix}:#{user_id}"

  defp normalize_export_name(name, requested_at) when is_binary(name) do
    case String.trim(name) do
      "" -> default_export_name(requested_at)
      value -> String.slice(value, 0, 160)
    end
  end

  defp normalize_export_name(_name, requested_at), do: default_export_name(requested_at)

  defp default_export_name(requested_at) do
    "Products export #{Calendar.strftime(requested_at, "%Y-%m-%d %H:%M")}"
  end

  defp build_file_name(name, requested_at) do
    slug =
      name
      |> slugify()
      |> String.slice(0, 80)
      |> case do
        "" -> "products-export"
        value -> value
      end

    "#{slug}-#{Calendar.strftime(requested_at, "%Y%m%d-%H%M%S")}.zip"
  end

  defp slugify(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^\p{L}\p{N}\s-]/u, "")
    |> String.replace(~r/[\s_-]+/u, "-")
    |> String.trim("-")
  end

  defp maybe_put_filter(map, _key, false), do: map
  defp maybe_put_filter(map, _key, nil), do: map
  defp maybe_put_filter(map, key, value), do: Map.put(map, key, value)

  defp maybe_add_detail(details, _label, nil), do: details
  defp maybe_add_detail(details, _label, ""), do: details

  defp maybe_add_detail(details, label, value) do
    details ++ [%{label: label, value: format_detail_value(label, value)}]
  end

  defp format_detail_value("Status", value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_detail_value(_label, value), do: to_string(value)

  defp sort_label(filter_params) do
    sort = Map.get(filter_params, "sort")
    dir = Map.get(filter_params, "dir")

    cond do
      is_binary(sort) and is_binary(dir) ->
        "#{sort} #{String.upcase(dir)}"

      is_binary(sort) ->
        sort

      is_binary(dir) ->
        "updated_at #{String.upcase(dir)}"

      true ->
        nil
    end
  end

  defp filter_value(filters, "status"),
    do: Map.get(filters, "status") || Map.get(filters, :status)

  defp filter_value(filters, "query"), do: Map.get(filters, "query") || Map.get(filters, :query)

  defp filter_value(filters, "updated_from") do
    Map.get(filters, "updated_from") || Map.get(filters, :updated_from)
  end

  defp filter_value(filters, "updated_to") do
    Map.get(filters, "updated_to") || Map.get(filters, :updated_to)
  end

  defp filter_value(filters, "sort"), do: Map.get(filters, "sort") || Map.get(filters, :sort)
  defp filter_value(filters, "dir"), do: Map.get(filters, "dir") || Map.get(filters, :dir)

  defp normalize_filter_status(status) when status in @allowed_statuses, do: status
  defp normalize_filter_status(_status), do: "all"

  defp normalize_filter_query(query) when is_binary(query) do
    case String.trim(query) do
      "" -> nil
      value -> value
    end
  end

  defp normalize_filter_query(_query), do: nil

  defp normalize_filter_date(%Date{} = date), do: Date.to_iso8601(date)

  defp normalize_filter_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> Date.to_iso8601(parsed_date)
      _other -> nil
    end
  end

  defp normalize_filter_date(_date), do: nil

  defp normalize_filter_sort(sort) when sort in @allowed_sorts, do: sort
  defp normalize_filter_sort(_sort), do: "updated_at"

  defp normalize_filter_sort_dir(sort_dir) when sort_dir in @allowed_sort_dirs, do: sort_dir
  defp normalize_filter_sort_dir(_sort_dir), do: "desc"

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _other -> nil
    end
  end

  defp parse_date(_value), do: nil

  defp normalize_download_payload(payload) when is_map(payload) do
    download_url = Map.get(payload, :download_url) || Map.get(payload, "download_url")

    if is_binary(download_url) do
      {:ok,
       %{
         download_url: download_url,
         link_expires_at:
           payload
           |> Map.get(:expires_at)
           |> Kernel.||(Map.get(payload, "expires_at"))
           |> parse_optional_datetime()
       }}
    else
      {:error, :invalid_download_payload}
    end
  end

  defp normalize_download_payload(_payload), do: {:error, :invalid_download_payload}

  defp fallback_download_details(%Export{} = export, opts) do
    case Media.public_url_for_storage_key(export.storage_key, opts) do
      {:ok, download_url} -> {:ok, %{download_url: download_url, link_expires_at: nil}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp persist_failed_export(%Export{} = export, error_message) do
    export
    |> Export.update_changeset(%{
      "status" => "failed",
      "error_message" => error_message
    })
    |> Repo.update()
    |> broadcast_update_result()
  rescue
    error in Postgrex.Error ->
      if legacy_error_message_overflow?(error, error_message) do
        export
        |> Export.update_changeset(%{
          "status" => "failed",
          "error_message" =>
            normalize_error_message(error_message, @legacy_db_error_message_length)
        })
        |> Repo.update()
        |> broadcast_update_result()
      else
        reraise error, __STACKTRACE__
      end
  end

  defp normalize_error_message(error_message, limit) do
    error_message = String.trim(error_message)

    cond do
      error_message == "" ->
        "Unknown export failure"

      String.length(error_message) <= limit ->
        error_message

      limit <= 3 ->
        String.slice(error_message, 0, limit)

      true ->
        String.slice(error_message, 0, limit - 3) <> "..."
    end
  end

  defp legacy_error_message_overflow?(
         %Postgrex.Error{postgres: %{code: :string_data_right_truncation}},
         error_message
       ) do
    String.length(error_message) > @legacy_db_error_message_length
  end

  defp legacy_error_message_overflow?(_error, _error_message), do: false

  defp parse_optional_datetime(nil), do: nil

  defp parse_optional_datetime(%DateTime{} = datetime), do: datetime

  defp parse_optional_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _other -> nil
    end
  end

  defp parse_optional_datetime(_value), do: nil

  defp now(nil), do: now()
  defp now(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
