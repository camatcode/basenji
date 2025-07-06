defmodule Basenji.Worker.ComicWorkerTest do
  use Basenji.DataCase

  alias Basenji.Comics
  alias Basenji.Worker.ComicWorker

  @moduletag :capture_log

  doctest ComicWorker

  test "extract_metadata" do
    %{resource_location: loc} = build(:comic)
    {:ok, %{title: nil, page_count: nil, format: nil} = comic} = Comics.create_comic(%{resource_location: loc})
    %{failure: 0} = TestHelper.drain_queue(:comic)

    {:ok, comic} = Comics.get_comic(comic.id)
    assert comic.title
    assert comic.format
    assert comic.page_count
  end

  test "delete" do
    %{resource_location: loc} = build(:comic)
    basename = Path.basename(loc)
    cp_to = Path.join(System.tmp_dir!(), basename)
    :ok = File.cp(loc, cp_to)
    on_exit(fn -> File.rm(cp_to) end)

    {:ok, comic} = Comics.from_resource(cp_to, %{})
    {:ok, _} = Comics.delete_comic(comic)

    TestHelper.drain_queue(:comic)

    refute File.exists?(cp_to)
  end
end
