defmodule Basenji.Worker.ComicWorkerTest do
  use Basenji.DataCase

  alias Basenji.Comics
  alias Basenji.Worker.ComicWorker

  @moduletag :capture_log

  doctest ComicWorker

  test "extract_metadata" do
    %{resource_location: loc} = build(:comic)
    {:ok, %{title: nil, page_count: -1, format: nil} = comic} = Comics.create_comic(%{resource_location: loc})
    %{failure: 0} = TestHelper.drain_queue(:comic)

    {:ok, comic} = Comics.get_comic(comic.id)
    assert comic.title
    assert comic.format
    assert comic.page_count
  end

  test "snapshot" do
    %{resource_location: loc} = build(:comic)
    {:ok, %{image_preview_id: nil} = comic} = Comics.create_comic(%{resource_location: loc})
    %{failure: 0} = TestHelper.drain_queue(:comic)
    {:ok, %{image_preview_id: pre_id}} = Comics.get_comic(comic.id)
    assert pre_id
    {:ok, bytes} = Comics.get_image_preview(comic.id)
    assert byte_size(bytes) > 0
  end

  test "delete" do
    allow_delete = Application.get_env(:basenji, :allow_delete_resources)
    Application.put_env(:basenji, :allow_delete_resources, true)

    %{resource_location: loc} = build(:comic)
    basename = Path.basename(loc)
    cp_to = Path.join(TestHelper.get_tmp_dir(), basename)
    :ok = File.cp(loc, cp_to)
    on_exit(fn -> File.rm(cp_to) end)

    {:ok, comic} = Comics.from_resource(cp_to, %{})
    {:ok, _} = Comics.delete_comic(comic, delete_resource: true)

    TestHelper.drain_queue(:comic)
    Application.put_env(:basenji, :allow_delete_resources, allow_delete)
    refute File.exists?(cp_to)
  end
end
