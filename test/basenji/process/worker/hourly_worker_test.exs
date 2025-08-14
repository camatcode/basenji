defmodule Basenji.Worker.HourlyWorkerTest do
  use Basenji.DataCase

  alias Basenji.Collections
  alias Basenji.Worker.HourlyWorker

  @moduletag :capture_log

  doctest HourlyWorker

  test "validates collections" do
    :ok = HourlyWorker.perform(%Oban.Job{})

    [collection] = Collections.list_collections()

    assert collection.resource_location == Basenji.Application.get_comics_directory()

    %{discard: 0, cancelled: 0, success: successes, failure: 0, snoozed: 0} =
      TestHelper.drain_queue(:collection)

    assert successes > 0
  end

  test "validates comics" do
    comics = insert_list(5, :comic)

    rm_files =
      comics
      |> Enum.map(fn comic -> comic.resource_location end)
      |> Enum.filter(fn loc -> String.starts_with?(loc, "/tmp") end)

    rm_files
    |> Enum.each(fn loc -> File.rm!(loc) end)

    :ok = HourlyWorker.perform(%Oban.Job{})

    comics
    |> Enum.each(fn comic ->
      assert {:error, :not_found} == Basenji.Comics.get_comic(comic.id)
    end)
  end
end
