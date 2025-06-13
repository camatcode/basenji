defmodule BasenjiWeb.ThumbnailController do
  use BasenjiWeb, :controller

  alias Basenji.Library

  def show(conn, %{"path" => encoded_path}) do
    try do
      # Decode the comic path
      comic_path = Base.url_decode64!(encoded_path)

      # Check if file exists and is a comic
      if File.exists?(comic_path) and Library.is_comic_file?(comic_path) do
        case Library.generate_thumbnail_binary(comic_path) do
          {:ok, {image_data, content_type}} ->
            conn
            |> put_resp_content_type(content_type)
            |> put_resp_header("cache-control", "public, max-age=3600")
            |> send_resp(200, image_data)

          {:error, _reason} ->
            # Return placeholder image
            send_placeholder(conn)
        end
      else
        send_placeholder(conn)
      end
    rescue
      _ ->
        send_placeholder(conn)
    end
  end

  defp send_placeholder(conn) do
    # Create a simple SVG placeholder
    placeholder_svg = """
    <svg width="300" height="400" viewBox="0 0 300 400" xmlns="http://www.w3.org/2000/svg">
      <rect width="300" height="400" fill="#e5e7eb"/>
      <path d="M75 150h150v100H75z" fill="#9ca3af"/>
      <text x="150" y="280" text-anchor="middle" font-family="Arial" font-size="14" fill="#6b7280">Comic</text>
    </svg>
    """

    conn
    |> put_resp_content_type("image/svg+xml")
    |> send_resp(200, placeholder_svg)
  end
end
