ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start(timeout: :infinity)
Ecto.Adapters.SQL.Sandbox.mode(Basenji.Repo, :manual)
