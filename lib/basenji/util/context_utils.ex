defmodule Basenji.ContextUtils do
  @moduledoc false

  import Ecto.Query, warn: false

  defp safe_to_existing_atom(thing) do
    String.to_existing_atom(thing)
  rescue
    _ -> nil
  end

  defp expand_search_opts(opts) do
    if is_map(opts[:search]) do
      expanded = Keyword.new(opts[:search], fn {k, v} -> {safe_to_existing_atom(k), v} end)

      Keyword.merge(expanded, opts)
      |> Keyword.delete(:search)
    else
      opts
    end
  end

  def reduce_opts(query, opts) do
    opts = expand_search_opts(opts)

    q =
      Enum.reduce(opts, query, fn
        {_any, ""}, query ->
          query

        {_any, nil}, query ->
          query

        {:inserted_before, dt}, query ->
          where(query, [c], c.inserted_at < ^dt)

        {:inserted_after, dt}, query ->
          where(query, [c], c.inserted_at > ^dt)

        {:updated_before, dt}, query ->
          where(query, [c], c.updated_at < ^dt)

        {:updated_after, dt}, query ->
          where(query, [c], c.updated_at > ^dt)

        {:offset, offset}, query when offset > 0 ->
          offset(query, [p], ^offset)

        {:order_by, order}, query when is_bitstring(order) ->
          order_by(query, [], ^safe_to_existing_atom(order))

        {:order_by, order}, query when is_atom(order) ->
          order_by(query, [], ^order)

        {:preload, pre}, query ->
          preload(query, [], ^pre)

        {:limit, lim}, query ->
          limit(query, [], ^lim)

        _, query ->
          query
      end)

    {q, opts}
  end
end
