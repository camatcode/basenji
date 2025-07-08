ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start(timeout: :infinity)
Ecto.Adapters.SQL.Sandbox.mode(Basenji.Repo, :manual)

defmodule TestHelper do
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
