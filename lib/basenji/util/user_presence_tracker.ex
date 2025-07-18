defmodule Basenji.UserPresenceTracker do
  @moduledoc false

  use Phoenix.Tracker

  alias __MODULE__, as: UserPresenceTracker

  @topic "browsers"

  def start_link(opts) do
    opts = Keyword.merge([name: UserPresenceTracker], opts)
    Phoenix.Tracker.start_link(UserPresenceTracker, opts, opts)
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server}}
  end

  def handle_diff(_diff, state), do: {:ok, state}

  def track_presence(pid) do
    Phoenix.Tracker.track(UserPresenceTracker, pid, @topic, inspect(pid), %{})
  end

  def anyone_browsing? do
    case Phoenix.Tracker.list(UserPresenceTracker, @topic) do
      [] -> false
      _ -> true
    end
  end
end
