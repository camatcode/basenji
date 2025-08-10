defmodule Basenji.ValidatorTest do
  use Basenji.DataCase

  alias Basenji.Validator

  @moduletag :capture_log

  doctest Validator

  test "can validate" do
    Validator.start_link(%{})
    Validator.seed()

    %{discard: 0, cancelled: 0, success: successes, failure: 0, snoozed: 0} =
      TestHelper.drain_queue(:scheduled)

    assert successes > 0
  end
end
