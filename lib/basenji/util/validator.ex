defmodule Basenji.Validator do
  @moduledoc false

  use GenServer

  alias Basenji.Validator
  alias Basenji.Worker.HourlyWorker

  require Logger

  def start_link(state) do
    GenServer.start_link(Validator, state, name: Validator)
  end

  def seed do
    GenServer.cast(Validator, :seed)
  end

  def init(_opts) do
    seed()
    {:ok, %{}}
  end

  def handle_cast(:seed, state) do
    HourlyWorker.new(%{})
    |> Oban.insert()

    {:noreply, state}
  end
end
