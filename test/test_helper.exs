ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start(timeout: :infinity)
Ecto.Adapters.SQL.Sandbox.mode(Basenji.Repo, :manual)

defmodule TestHelper do
  def drain_queue(queue, start_opts \\ [], drain_opts \\ []) do
    start_opts = Keyword.merge([limit: 10], start_opts) |> Keyword.put(:queue, queue)
    drain_opts = Keyword.merge([with_scheduled: true], drain_opts) |> Keyword.put(:queue, queue)
    Oban.start_queue(start_opts)
    Oban.drain_queue(drain_opts)
  end
end
