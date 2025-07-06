defmodule Basenji.ProcessorTest do
  use Basenji.DataCase

  alias Basenji.Processor

  doctest Processor

  test "submit comic jobs" do
    comic = insert(:comic)
    jobs = Processor.process(comic, [:insert])

    refute Enum.empty?(jobs)
    TestHelper.drain_queue(:comic)
  end
end
