defmodule Basenji.ContextUtils do
  @moduledoc false

  import Ecto.Query, warn: false

  def reduce_opts(query, opts) do
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

      {:offset, offset}, query ->
        offset(query, [p], ^offset)

      {:order_by, order}, query ->
        order =
          "#{order}"
          |> String.to_existing_atom()

        order_by(query, [], ^order)

      {:preload, pre}, query ->
        preload(query, [], ^pre)

      {:limit, lim}, query ->
        limit(query, [], ^lim)

      _, query ->
        query
    end)
  end
end
