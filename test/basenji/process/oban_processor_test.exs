defmodule Basenji.ObanProcessorTest do
  use Basenji.DataCase

  alias Basenji.ObanProcessor

  doctest ObanProcessor

  test "submit comic jobs" do
    comic = insert(:comic)
    jobs = ObanProcessor.process(comic, [:insert])

    refute Enum.empty?(jobs)
    %{failure: 0} = TestHelper.drain_queue(:comic)
  end
end
