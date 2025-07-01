defmodule BasenjiWeb.HomeLive do
  @moduledoc false
  use BasenjiWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Hello World!</h1>
    """
  end
end
