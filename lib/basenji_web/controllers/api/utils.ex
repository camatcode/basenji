defmodule BasenjiWeb.API.Utils do
  @moduledoc false

  import Ecto.Changeset
  import Phoenix.Controller
  import Plug.Conn

  alias Basenji.Comics

  require Logger

  def atomize(m) when is_map(m) do
    m
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  def get_comic_page_from_cache(comic_id, page_num) do
    Cachex.fetch(
      :basenji_cache,
      %{comic_id: comic_id, page_num: page_num, optimized: true},
      fn _key ->
        Comics.get_page(comic_id, page_num)
        |> case do
          {:ok, page, mime} ->
            {:commit, {page, mime}, [ttl: to_timeout(minute: 5)]}

          {_, resp} ->
            {:ignore, {:error, resp}}
        end
      end
    )
    |> case do
      {:ignore, {:error, error}} ->
        {:error, error}

      {_, {page, mime}} ->
        {:ok, page, mime}

      response ->
        response
    end
  end

  def validate_request_params(params, types, required_params) do
    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required(required_params)
    |> apply_action(:validate)
  end

  def safe_to_int(str) when is_bitstring(str) do
    result = str |> String.trim() |> String.to_integer()
    {:ok, result}
  rescue
    _ -> {:error, :not_int}
  end

  def bad_request_handler(conn, error) do
    case error do
      {:error, msg} when is_binary(msg) or is_atom(msg) ->
        conn
        |> put_status(400)
        |> json(%{error: msg})

      {:error, changeset} when is_map(changeset) ->
        %{errors: errors} = changeset
        Logger.error(inspect(errors))

        conn
        |> put_status(400)
        |> json(%{error: inspect(errors)})

      error ->
        Logger.error("Something went wrong, got: " <> inspect(error))

        conn
    end
  end

  def to_opts(plug_info) do
    plug_info
    |> Map.from_struct()
    |> Enum.reduce([], &apply_opts/2)
  end

  defp apply_opts({:filter, filter}, opts) do
    Keyword.merge([search: filter], opts)
  end

  defp apply_opts({:page, %{"limit" => limit, "offset" => offset}}, opts) do
    Keyword.merge([offset: offset, limit: limit], opts)
  end

  defp apply_opts({:include, v}, opts) do
    Keyword.merge([preload: v], opts)
  end

  defp apply_opts({:sort, v}, opts) do
    Keyword.merge([order_by: v], opts)
  end

  defp apply_opts(_any, opts) do
    opts
  end
end
