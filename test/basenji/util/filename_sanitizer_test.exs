defmodule Basenji.FilenameSanitizerTest do
  use ExUnit.Case

  alias Basenji.FilenameSanitizer

  @moduletag :capture_log

  doctest FilenameSanitizer

  test "sanitizes wild filenames" do
    assert "Hello_World_2104" ==
             FilenameSanitizer.sanitize("Hello World! (Reprise)_2104 `ùúûü.cbz",
               remove_extension: true,
               preserve_case: true,
               max_length: 20
             )
  end
end
