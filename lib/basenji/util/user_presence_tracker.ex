defmodule Basenji.UserPresenceTracker do
  @moduledoc false

  use Phoenix.Tracker

  alias __MODULE__, as: UserPresenceTracker
  alias Phoenix.Tracker

  @topic "browsers"

  def start_link(opts) do
    opts = Keyword.put(opts, :name, UserPresenceTracker)
    Tracker.start_link(UserPresenceTracker, opts, opts)
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server}}
  end

  def handle_diff(_diff, state), do: {:ok, state}

  def track_presence(pid), do: Tracker.track(UserPresenceTracker, pid, @topic, pid, %{})

  def anyone_browsing?, do: !Enum.empty?(Tracker.list(UserPresenceTracker, @topic))
end
