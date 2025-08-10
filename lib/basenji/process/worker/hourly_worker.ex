defmodule Basenji.Worker.HourlyWorker do
  @moduledoc false

  use Oban.Worker, queue: :scheduled, max_attempts: 3
  use Basenji.TelemetryHelpers

  alias Basenji.Application
  alias Basenji.Collections
  alias Basenji.Comics

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{} = _job) do
    validate_collections()
    validate_comics()
  end

  defp validate_collections do
    ensure_root_collection()

    Collections.list_collections()
    |> Basenji.ObanProcessor.process([:explore_resource])
  end

  defp ensure_root_collection do
    comics_dir = Application.get_comics_directory()

    with [] <- Collections.list_collections(resource_location: comics_dir) do
      Collections.create_collection(%{title: "My Comics", resource_location: comics_dir})
    end

    :ok
  end

  defp validate_comics do
    Comics.list_comics()
    |> Enum.reject(fn comic -> bytes_exist?(comic.resource_location) end)
    |> Enum.each(fn comic -> Comics.delete_comic(comic) end)

    :ok
  end

  defp bytes_exist?(location) do
    File.exists?(location)
  end
end
