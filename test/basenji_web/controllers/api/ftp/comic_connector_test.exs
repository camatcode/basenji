defmodule BasenjiWeb.FTP.ComicConnectorTest do
  use ExUnit.Case

  alias BasenjiWeb.FTP.ComicConnector

  @moduletag :capture_log

  doctest ComicConnector

  test "get_cwd" do
    cwd = "/"
    connector_state = %{current_working_directory: cwd}
    ^cwd = ComicConnector.get_working_directory(connector_state)

    cwd = "/comics"
    connector_state = %{current_working_directory: cwd}
    ^cwd = ComicConnector.get_working_directory(connector_state)

    cwd = "/comics/by-id/"
    connector_state = %{current_working_directory: cwd}
    ^cwd = ComicConnector.get_working_directory(connector_state)

    cwd = "/comics/invalid"
    connector_state = %{current_working_directory: cwd}
    assert "/" == ComicConnector.get_working_directory(connector_state)
  end

  test "directory_exists?" do
    assert ComicConnector.directory_exists?("/", %{})
    assert ComicConnector.directory_exists?("/comics", %{})
    assert ComicConnector.directory_exists?("/collections", %{})
    refute ComicConnector.directory_exists?("/invalid", %{})
  end
end
