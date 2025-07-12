ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start(timeout: :infinity)
Ecto.Adapters.SQL.Sandbox.mode(Basenji.Repo, :manual)

defmodule TestHelper do
  def get_tmp_dir, do: Path.join(System.tmp_dir!(), "basenji")

  def drain_queue(queue, start_opts \\ [], drain_opts \\ [])

  def drain_queue(:comic, start_opts, drain_opts) do
    start_opts = Keyword.merge([limit: 10], start_opts) |> Keyword.put(:queue, :comic)
    drain_opts = Keyword.merge([with_scheduled: true], drain_opts) |> Keyword.put(:queue, :comic)
    %{discard: dis_1, cancelled: can_1, success: suc_1, failure: fail_1, snoozed: snoozed_1} = drain(start_opts, drain_opts)
    start_opts = Keyword.merge([limit: 10], start_opts) |> Keyword.put(:queue, :comic_low)
    drain_opts = Keyword.merge([with_scheduled: true], drain_opts) |> Keyword.put(:queue, :comic_low)

    %{discard: dis_2, cancelled: can_2, success: suc_2, failure: fail_2, snoozed: snoozed_2} = drain(start_opts, drain_opts)

    %{
      discard: dis_1 + dis_2,
      cancelled: can_1 + can_2,
      success: suc_1 + suc_2,
      failure: fail_1 + fail_2,
      snoozed: snoozed_1 + snoozed_2
    }
  end

  def drain_queue(queue, start_opts, drain_opts) do
    start_opts = Keyword.merge([limit: 10], start_opts) |> Keyword.put(:queue, queue)
    drain_opts = Keyword.merge([with_scheduled: true], drain_opts) |> Keyword.put(:queue, queue)
    drain(start_opts, drain_opts)
  end

  def drain_queues(queues, start_opts \\ [], drain_opts \\ []) do
    results =
      queues
      |> Enum.map(fn queue -> drain_queue(queue, start_opts, drain_opts) end)

    maybe_drain_again?(results, queues, start_opts, drain_opts)
  end

  defp maybe_drain_again?(results, queues, start_opts, drain_opts) do
    all_clear =
      results
      |> Enum.filter(fn %{success: s} -> s > 0 end)
      |> Enum.empty?()

    if all_clear do
      results
    else
      drain_queues(queues, start_opts, drain_opts)
    end
  end

  defp drain(start_opts, drain_opts) do
    Oban.start_queue(start_opts)
    Oban.drain_queue(drain_opts)
  end
end

defmodule TestHelper.GraphQL do
  use BasenjiWeb.ConnCase

  def execute_query(api_path, conn, query) do
    conn
    |> post(api_path, %{query: query})
    |> json_response(200)
  end

  def build_query(field_name \\ "comics", args \\ "", fields \\ "id") do
    args_str = if args == "", do: "", else: "(#{args})"

    """
    {
      #{field_name}#{args_str} {
        #{fields}
      }
    }
    """
  end

  def build_search_query(field, value, fields \\ "id") do
    formatted_value = format_graphql_value(value)
    build_query("comics", "#{field}: #{formatted_value}", fields)
  end

  def build_search_query_for(query_name, field, value, fields \\ "id") do
    formatted_value = format_graphql_value(value)
    build_query(query_name, "#{field}: #{formatted_value}", fields)
  end

  defp format_graphql_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_graphql_value(value) when is_atom(value), do: value |> to_string() |> String.upcase()
  defp format_graphql_value(value), do: to_string(value)

  def assert_comic_in_response(response, comic_id, query_name \\ "comics") do
    %{"data" => %{^query_name => found}} = response
    assert Enum.member?(found, %{"id" => comic_id})
  end

  def assert_exact_comic_match(response, comic_id, query_name \\ "comics") do
    %{"data" => %{^query_name => [%{"id" => ^comic_id}]}} = response
  end

  def assert_single_comic(response, comic_id, query_name) do
    %{"data" => %{^query_name => %{"id" => ^comic_id}}} = response
  end

  def assert_single_object(response, object_id, query_name) do
    %{"data" => %{^query_name => %{"id" => ^object_id}}} = response
  end

  def assert_exact_collection_match(response, collection_id) do
    %{"data" => %{"collections" => [%{"id" => ^collection_id}]}} = response
  end
end

defmodule TestHelper.JSONAPI do
  def build_request_body(resource_type, id \\ nil, attributes \\ %{}, relationships \\ %{}) do
    %{"type" => resource_type}
    |> maybe_put("id", id)
    |> maybe_put("attributes", attributes)
    |> maybe_put("relationships", relationships)
    |> then(fn data -> %{"data" => data} end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, value) when value == %{}, do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  def build_comics_relationship(comic_ids) when is_list(comic_ids) do
    comics_data = Enum.map(comic_ids, fn id -> %{"type" => "comic", "id" => id} end)
    %{"comics" => %{"data" => comics_data}}
  end

  def build_comics_relationship(comic_id) when is_binary(comic_id) do
    build_comics_relationship([comic_id])
  end

  def build_comics_relationship(_), do: %{}
end
