defmodule BasenjiWeb.ComicReaderLive do
  use BasenjiWeb, :live_view
  import BasenjiWeb.ComicComponents

  alias BasenjiWeb.ComicReaderLive.{ComicProcessor, NavigationHelpers}

  require Logger

  @impl true
  def mount(params, _session, socket) do
    from_source = Map.get(params, "from", "uploader")

    socket =
      socket
      |> assign(:uploaded_files, [])
      |> assign(:current_comic, nil)
      |> assign(:pages, [])
      |> assign(:current_page, 0)
      |> assign(:total_pages, 0)
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:reading_mode, "single")
      |> assign(:from_source, from_source)
      |> allow_upload(:comic_file,
        accept: :any,
        max_entries: 1,
        max_file_size: 100 * 1024 * 1024 * 100
      )

    # Check if a comic path was provided in the URL
    case Map.get(params, "comic") do
      nil ->
        {:ok, socket}

      comic_path ->
        decoded_path = URI.decode(comic_path)

        if File.exists?(decoded_path) do
          send(self(), {:load_comic, decoded_path})
          {:ok, assign(socket, :loading, true)}
        else
          {:ok, put_flash(socket, :error, "Comic file not found: #{decoded_path}")}
        end
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # Custom validation for comic book file extensions
    socket =
      socket.assigns.uploads.comic_file.entries
      |> Enum.reduce(socket, fn entry, acc_socket ->
        if ComicProcessor.supported_comic_extension?(entry.client_name) do
          acc_socket
        else
          cancel_upload(acc_socket, :comic_file, entry.ref)
        end
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :comic_file, fn %{path: path}, entry ->
        dest = Path.join(System.tmp_dir(), "basenji_#{entry.uuid}_#{entry.client_name}")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    case uploaded_files do
      [file_path] ->
        send(self(), {:load_comic, file_path})
        {:noreply, assign(socket, :loading, true)}

      [] ->
        {:noreply, put_flash(socket, :error, "No file uploaded")}

      _ ->
        {:noreply, put_flash(socket, :error, "Please upload only one file at a time")}
    end
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    %{current_page: current_page, total_pages: total_pages, reading_mode: reading_mode} =
      socket.assigns

    new_page = NavigationHelpers.next_page(current_page, total_pages, reading_mode)

    # Load the page if not already loaded
    socket = ensure_page_loaded(socket, new_page)

    # Preload upcoming pages
    preload_indices = get_preload_indices(new_page, total_pages, 2)
    send(self(), {:preload_pages, preload_indices})

    {:noreply, assign(socket, :current_page, new_page)}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    %{current_page: current_page, reading_mode: reading_mode} = socket.assigns

    new_page = NavigationHelpers.prev_page(current_page, reading_mode)

    # Load the page if not already loaded
    socket = ensure_page_loaded(socket, new_page)

    # Preload nearby pages
    preload_indices = get_preload_indices(new_page, socket.assigns.total_pages, 2)
    send(self(), {:preload_pages, preload_indices})

    {:noreply, assign(socket, :current_page, new_page)}
  end

  @impl true
  def handle_event("go_to_page", %{"page" => page_str}, socket) do
    %{total_pages: total_pages} = socket.assigns

    case NavigationHelpers.parse_page_number(page_str, total_pages) do
      {:ok, page_index} ->
        # Load the page if not already loaded
        socket = ensure_page_loaded(socket, page_index)

        # Preload nearby pages
        preload_indices = get_preload_indices(page_index, total_pages, 2)
        send(self(), {:preload_pages, preload_indices})

        {:noreply, assign(socket, :current_page, page_index)}

      {:error, error_message} ->
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  @impl true
  def handle_event("change_reading_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :reading_mode, mode)}
  end

  @impl true
  def handle_event("close_comic", _params, socket) do
    # Clean up temporary files
    if socket.assigns.current_comic do
      ComicProcessor.cleanup_comic_files(socket.assigns.current_comic)
    end

    # Navigate back to appropriate location
    destination =
      case socket.assigns.from_source do
        "library" -> "/library"
        _ -> "/reader"
      end

    {:noreply,
     socket
     |> assign(:current_comic, nil)
     |> assign(:pages, [])
     |> assign(:current_page, 0)
     |> assign(:total_pages, 0)
     |> assign(:error, nil)
     |> push_navigate(to: destination)}
  end

  # Keyboard navigation - WASD controls
  @impl true
  def handle_event("keydown", %{"key" => "d"}, socket) do
    handle_event("next_page", %{}, socket)
  end

  def handle_event("keydown", %{"key" => "D"}, socket) do
    handle_event("next_page", %{}, socket)
  end

  def handle_event("keydown", %{"key" => "a"}, socket) do
    handle_event("prev_page", %{}, socket)
  end

  def handle_event("keydown", %{"key" => "A"}, socket) do
    handle_event("prev_page", %{}, socket)
  end

  # Keep original arrow keys too
  def handle_event("keydown", %{"key" => "ArrowRight"}, socket) do
    handle_event("next_page", %{}, socket)
  end

  def handle_event("keydown", %{"key" => "ArrowLeft"}, socket) do
    handle_event("prev_page", %{}, socket)
  end

  def handle_event("keydown", %{"key" => " "}, socket) do
    handle_event("next_page", %{}, socket)
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    handle_event("close_comic", %{}, socket)
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_comic, file_path}, socket) do
    case ComicProcessor.get_comic_metadata(file_path) do
      {:ok, {pages, _metadata}} ->
        Logger.info("Comic metadata loaded",
          file_path: file_path,
          page_count: length(pages)
        )

        # Load the first page immediately
        first_page = Enum.at(pages, 0)

        case ComicProcessor.load_page(first_page) do
          {:ok, loaded_page} ->
            updated_pages = List.replace_at(pages, 0, loaded_page)

            # Preload next few pages in background
            send(self(), {:preload_pages, [1, 2]})

            {:noreply,
             socket
             |> assign(:current_comic, file_path)
             |> assign(:pages, updated_pages)
             |> assign(:current_page, 0)
             |> assign(:total_pages, length(pages))
             |> assign(:loading, false)
             |> assign(:error, nil)
             |> put_flash(:info, "Comic loaded: #{Path.basename(file_path)}")}

          {:error, reason} ->
            Logger.error("Failed to load first page", error: inspect(reason))

            {:noreply,
             socket
             |> assign(:loading, false)
             |> assign(:error, "Failed to load first page: #{inspect(reason)}")
             |> put_flash(:error, "Could not load comic file")}
        end

      {:error, reason} ->
        Logger.error("Failed to load comic metadata",
          file_path: file_path,
          error: inspect(reason)
        )

        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, "Failed to load comic: #{inspect(reason)}")
         |> put_flash(:error, "Could not load comic file")}
    end
  end

  @impl true
  def handle_info({:preload_pages, indices}, socket) do
    # Preload pages in background without blocking UI
    Task.start(fn ->
      Enum.each(indices, fn index ->
        if index >= 0 and index < socket.assigns.total_pages do
          page_info = Enum.at(socket.assigns.pages, index)

          if page_info && !page_info.data_url do
            case ComicProcessor.load_page(page_info) do
              {:ok, loaded_page} ->
                send(self(), {:page_loaded, index, loaded_page})

              {:error, _reason} ->
                # Ignore preload errors to not disrupt reading
                :ok
            end
          end
        end
      end)
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_loaded, index, loaded_page}, socket) do
    updated_pages = List.replace_at(socket.assigns.pages, index, loaded_page)
    {:noreply, assign(socket, :pages, updated_pages)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <html lang="en" class="h-full">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <.live_title>
          Basenji Comic Reader
        </.live_title>
        <link phx-track-static rel="stylesheet" href="/assets/app.css" />
        <script defer phx-track-static type="text/javascript" src="/assets/app.js">
        </script>
      </head>
      <body class="h-full overflow-hidden bg-gray-900 text-white" phx-window-keydown="keydown">
        <.flash_group flash={@flash} />

        <div class="h-screen flex flex-col">
          <.app_header
            current_comic={@current_comic}
            reading_mode={@reading_mode}
            current_page={@current_page}
            total_pages={@total_pages}
          />

          <div class="flex-1 overflow-hidden">
            <%= cond do %>
              <% @loading -> %>
                <.loading_spinner />
              <% @error -> %>
                <.error_display error={@error} />
              <% @current_comic && !Enum.empty?(@pages) -> %>
                <.comic_reader
                  pages={@pages}
                  current_page={@current_page}
                  total_pages={@total_pages}
                  reading_mode={@reading_mode}
                />
              <% true -> %>
                <.comic_uploader uploads={@uploads} />
            <% end %>
          </div>
        </div>
      </body>
    </html>
    """
  end

  # Helper functions for lazy loading
  defp ensure_page_loaded(socket, page_index) do
    page_info = Enum.at(socket.assigns.pages, page_index)

    if page_info && !page_info.data_url do
      case ComicProcessor.load_page(page_info) do
        {:ok, loaded_page} ->
          updated_pages = List.replace_at(socket.assigns.pages, page_index, loaded_page)
          assign(socket, :pages, updated_pages)

        {:error, _reason} ->
          # If page fails to load, keep the socket as-is
          socket
      end
    else
      socket
    end
  end

  defp get_preload_indices(current_page, total_pages, lookahead) do
    start_index = max(0, current_page - 1)
    end_index = min(total_pages - 1, current_page + lookahead)

    Enum.to_list(start_index..end_index)
    # Don't preload current page
    |> Enum.reject(&(&1 == current_page))
  end
end
