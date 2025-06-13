defmodule BasenjiWeb.ComicComponents do
  @moduledoc """
  Comic reader UI components.
  """
  use Phoenix.Component
  use BasenjiWeb, :html

  @doc """
  Renders the comic upload interface.
  """
  attr :uploads, :map, required: true

  def comic_uploader(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full p-8 bg-gray-900">
      <div class="max-w-md w-full">
        <div class="text-center mb-8">
          <svg class="w-20 h-20 mx-auto text-gray-400 mb-4" fill="currentColor" viewBox="0 0 24 24">
            <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />
          </svg>
          <h2 class="text-2xl font-bold mb-2">Upload a Comic</h2>
          <p class="text-gray-400">
            Select a comic book file to start reading<br /> Supported formats: CBZ, CBR, CB7, CBT
          </p>
        </div>

        <form phx-submit="upload" phx-change="validate">
          <div class="border-2 border-dashed border-gray-600 rounded-lg p-8 text-center hover:border-gray-500 transition-colors">
            <.live_file_input upload={@uploads.comic_file} class="hidden" />

            <label for={@uploads.comic_file.ref} class="cursor-pointer">
              <svg
                class="w-12 h-12 mx-auto text-gray-400 mb-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                />
              </svg>
              <span class="text-lg font-medium">Click to upload</span>
              <p class="text-sm text-gray-400 mt-2">
                or drag and drop your comic file here
              </p>
            </label>
          </div>

          <.upload_errors2 uploads={@uploads} />
          <.upload_progress uploads={@uploads} />

          <%= if !Enum.empty?(@uploads.comic_file.entries) do %>
            <button
              type="submit"
              class="w-full mt-6 px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded font-medium transition-colors"
            >
              Load Comic
            </button>
          <% end %>
        </form>

        <div class="mt-8 text-sm text-gray-400">
          <p class="font-medium mb-2">Keyboard Controls:</p>
          <ul class="space-y-1">
            <li>A / D keys: Navigate pages</li>
            <li>← / → Arrow keys: Navigate pages</li>
            <li>Spacebar: Next page</li>
            <li>Esc: Close comic</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders upload errors.
  """
  attr :uploads, :map, required: true

  def upload_errors2(assigns) do
    ~H"""
    <%= for entry <- @uploads.comic_file.entries do %>
      <%= for error <- upload_errors(@uploads.comic_file, entry) do %>
        <div class="mt-4 p-3 bg-red-900 border border-red-700 rounded text-red-200">
          {error_to_string(error)}
        </div>
      <% end %>
    <% end %>
    """
  end

  @doc """
  Renders upload progress.
  """
  attr :uploads, :map, required: true

  def upload_progress(assigns) do
    ~H"""
    <%= for entry <- @uploads.comic_file.entries do %>
      <div class="mt-4">
        <div class="flex items-center justify-between text-sm">
          <span class="text-gray-300">{entry.client_name}</span>
          <span class="text-gray-400">{entry.progress}%</span>
        </div>
        <div class="w-full bg-gray-700 rounded-full h-2 mt-1">
          <div
            class="bg-blue-600 h-2 rounded-full transition-all duration-300"
            style={"width: #{entry.progress}%"}
          >
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders the comic viewer with overlay controls.
  """
  attr :pages, :list, required: true
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :reading_mode, :string, required: true
  attr :show_controls, :boolean, required: true
  attr :current_comic, :string, required: true

  def comic_viewer(assigns) do
    ~H"""
    <div class="h-full w-full relative">
      <!-- Comic Display -->
      <div class="h-full w-full">
        <div class={reading_container_class(@reading_mode)}>
          <%= if @reading_mode == "double" && @current_page < @total_pages - 1 do %>
            <.double_page_view
              pages={@pages}
              current_page={@current_page}
              reading_mode={@reading_mode}
            />
          <% else %>
            <.single_page_view
              pages={@pages}
              current_page={@current_page}
              reading_mode={@reading_mode}
            />
          <% end %>
        </div>
      </div>
      
    <!-- Overlay Controls -->
      <div class={"absolute inset-0 pointer-events-none fade-out #{if @show_controls, do: "controls-visible", else: "controls-hidden"}"}>
        <.top_bar current_comic={@current_comic} reading_mode={@reading_mode} />
        <.bottom_bar current_page={@current_page} total_pages={@total_pages} />
        <.side_navigation current_page={@current_page} total_pages={@total_pages} />
      </div>
    </div>
    """
  end

  @doc """
  Renders single page view.
  """
  attr :pages, :list, required: true
  attr :current_page, :integer, required: true
  attr :reading_mode, :string, required: true

  def single_page_view(assigns) do
    ~H"""
    <%= if current_page = Enum.at(@pages, @current_page) do %>
      <%= if current_page.data_url do %>
        <img
          src={current_page.data_url}
          alt={"Page #{@current_page + 1}"}
          class={reading_mode_class(@reading_mode)}
          loading="lazy"
        />
      <% else %>
        <!-- Page loading placeholder -->
        <div class="flex items-center justify-center h-full">
          <div class="text-center">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4">
            </div>
            <p class="text-lg text-gray-300">Loading page #{@current_page + 1}...</p>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  @doc """
  Renders double page view.
  """
  attr :pages, :list, required: true
  attr :current_page, :integer, required: true
  attr :reading_mode, :string, required: true

  def double_page_view(assigns) do
    ~H"""
    <%= if current_page = Enum.at(@pages, @current_page) do %>
      <%= if current_page.data_url do %>
        <img
          src={current_page.data_url}
          alt={"Page #{@current_page + 1}"}
          class={reading_mode_class(@reading_mode)}
          loading="lazy"
        />
      <% else %>
        <div class="flex items-center justify-center h-full w-1/2">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
        </div>
      <% end %>
    <% end %>
    <%= if next_page = Enum.at(@pages, @current_page + 1) do %>
      <%= if next_page.data_url do %>
        <img
          src={next_page.data_url}
          alt={"Page #{@current_page + 2}"}
          class={reading_mode_class(@reading_mode)}
          loading="lazy"
        />
      <% else %>
        <div class="flex items-center justify-center h-full w-1/2">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
        </div>
      <% end %>
    <% end %>
    """
  end

  @doc """
  Renders the top control bar.
  """
  attr :current_comic, :string, required: true
  attr :reading_mode, :string, required: true

  def top_bar(assigns) do
    ~H"""
    <div class="absolute top-0 left-0 right-0 bg-gradient-to-b from-black/80 to-transparent p-4 pointer-events-auto">
      <div class="flex items-center justify-between">
        <h1 class="text-lg font-semibold flex items-center">
          <a href="/" class="hover:text-gray-300 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 24 24">
              <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />
            </svg>
            Basenji
          </a>
          <span class="mx-2 text-gray-500">/</span>
          <span class="text-gray-300 text-sm">{Path.basename(@current_comic)}</span>
        </h1>

        <div class="flex items-center space-x-3">
          <select
            class="bg-gray-800/90 border border-gray-700 rounded px-2 py-1 text-sm"
            phx-change="change_reading_mode"
            name="mode"
          >
            <option value="single" selected={@reading_mode == "single"}>Single Page</option>
            <option value="double" selected={@reading_mode == "double"}>Double Page</option>
            <option value="fit-width" selected={@reading_mode == "fit-width"}>Fit Width</option>
            <option value="fit-height" selected={@reading_mode == "fit-height"}>Fit Height</option>
          </select>

          <button
            phx-click="close_comic"
            class="px-3 py-1 bg-red-600/90 hover:bg-red-700 rounded text-sm transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the bottom control bar.
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true

  def bottom_bar(assigns) do
    ~H"""
    <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-4 pointer-events-auto">
      <!-- Progress Bar -->
      <div class="w-full bg-gray-700/50 rounded-full h-1 mb-3">
        <div
          class="bg-blue-500 h-1 rounded-full transition-all duration-300"
          style={"width: #{(@current_page + 1) / @total_pages * 100}%"}
        >
        </div>
      </div>
      
    <!-- Navigation Controls -->
      <div class="flex items-center justify-center space-x-4">
        <button
          phx-click="prev_page"
          disabled={@current_page == 0}
          class="px-4 py-2 bg-gray-800/90 hover:bg-gray-700 disabled:bg-gray-800/50 disabled:cursor-not-allowed rounded transition-colors"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </button>

        <div class="flex items-center space-x-2 bg-gray-800/90 rounded px-3 py-1">
          <span class="text-sm">Page</span>
          <input
            type="number"
            value={@current_page + 1}
            min="1"
            max={@total_pages}
            class="w-16 px-2 py-1 bg-gray-700 border border-gray-600 rounded text-center text-sm"
            phx-blur="go_to_page"
            name="page"
          />
          <span class="text-sm">of {@total_pages}</span>
        </div>

        <button
          phx-click="next_page"
          disabled={@current_page >= @total_pages - 1}
          class="px-4 py-2 bg-gray-800/90 hover:bg-gray-700 disabled:bg-gray-800/50 disabled:cursor-not-allowed rounded transition-colors"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>
      
    <!-- Keyboard shortcuts hint -->
      <div class="text-center mt-2 text-xs text-gray-400">
        A/D or ← → Navigate • Space Next • Esc Close
      </div>
    </div>
    """
  end

  @doc """
  Renders invisible side navigation areas.
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true

  def side_navigation(assigns) do
    ~H"""
    <button
      phx-click="prev_page"
      class="absolute left-0 top-0 bottom-0 w-1/3 pointer-events-auto"
      disabled={@current_page == 0}
    >
    </button>
    <button
      phx-click="next_page"
      class="absolute right-0 top-0 bottom-0 w-1/3 pointer-events-auto"
      disabled={@current_page >= @total_pages - 1}
    >
    </button>
    """
  end

  @doc """
  Renders a loading spinner.
  """
  def loading_spinner(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full">
      <div class="text-center">
        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4">
        </div>
        <p class="text-lg">Loading comic...</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders an error state.
  """
  attr :error, :string, required: true

  def error_display(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full">
      <div class="text-center">
        <div class="text-red-500 mb-4">
          <svg class="w-16 h-16 mx-auto" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
          </svg>
        </div>
        <p class="text-lg text-red-400">Error: {@error}</p>
      </div>
    </div>
    """
  end

  # Helper functions
  defp reading_mode_class("single"), do: "max-h-screen max-w-screen object-contain mx-auto"
  defp reading_mode_class("double"), do: "max-h-screen max-w-[49vw] object-contain"
  defp reading_mode_class("fit-width"), do: "w-screen h-auto object-contain mx-auto"
  defp reading_mode_class("fit-height"), do: "h-screen w-auto object-contain mx-auto"

  defp reading_container_class("single"), do: "flex items-center justify-center h-full"
  defp reading_container_class("double"), do: "flex space-x-2 justify-center items-center h-full"

  defp reading_container_class("fit-width"),
    do: "flex flex-col items-center justify-start h-full overflow-y-auto"

  defp reading_container_class("fit-height"), do: "flex items-center justify-center h-full"

  @doc """
  Renders the main application header.
  """
  attr :current_comic, :string, default: nil
  attr :reading_mode, :string, default: "single"
  attr :current_page, :integer, default: 0
  attr :total_pages, :integer, default: 0

  def app_header(assigns) do
    ~H"""
    <div class="bg-gray-800 border-b border-gray-700 px-6 py-3 flex-shrink-0">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <h1 class="text-xl font-bold flex items-center">
            <svg class="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
              <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />
            </svg>
            <a href="/" class="hover:text-gray-300">Basenji</a>
          </h1>

          <%= if @current_comic do %>
            <a
              href="/library"
              class="inline-flex items-center px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm transition-colors"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 19l-7-7 7-7"
                />
              </svg>
              Back to Library
            </a>
          <% end %>
        </div>

        <%= if @current_comic do %>
          <.header_controls
            reading_mode={@reading_mode}
            current_page={@current_page}
            total_pages={@total_pages}
          />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders the header controls when a comic is loaded.
  """
  attr :reading_mode, :string, required: true
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true

  def header_controls(assigns) do
    ~H"""
    <div class="flex items-center space-x-4">
      <!-- Reading Mode Selector -->
      <select
        class="bg-gray-700 border border-gray-600 rounded px-2 py-1 text-sm"
        phx-change="change_reading_mode"
        name="mode"
      >
        <option value="single" selected={@reading_mode == "single"}>📖 Single</option>
        <option value="double" selected={@reading_mode == "double"}>📚 Double</option>
        <option value="fit-width" selected={@reading_mode == "fit-width"}>↔️ Fit Width</option>
        <option value="fit-height" selected={@reading_mode == "fit-height"}>↕️ Fit Height</option>
      </select>

      <.page_navigation current_page={@current_page} total_pages={@total_pages} />

      <button phx-click="close_comic" class="px-2 py-1 bg-red-600 hover:bg-red-700 rounded text-sm">
        Close
      </button>
    </div>
    """
  end

  @doc """
  Renders page navigation controls.
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true

  def page_navigation(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <button
        phx-click="prev_page"
        disabled={@current_page == 0}
        class="px-2 py-1 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed rounded text-sm"
      >
        ← Prev
      </button>

      <span class="text-sm whitespace-nowrap">
        <input
          type="number"
          value={@current_page + 1}
          min="1"
          max={@total_pages}
          class="w-12 px-1 py-1 bg-gray-700 border border-gray-600 rounded text-center text-xs"
          phx-blur="go_to_page"
          name="page"
        /> / {@total_pages}
      </span>

      <button
        phx-click="next_page"
        disabled={@current_page >= @total_pages - 1}
        class="px-2 py-1 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed rounded text-sm"
      >
        Next →
      </button>
    </div>
    """
  end

  @doc """
  Renders the main comic reader area.
  """
  attr :pages, :list, required: true
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :reading_mode, :string, required: true

  def comic_reader(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Comic Display -->
      <div class="flex-1 bg-black overflow-hidden">
        <div class={reading_container_class(@reading_mode)}>
          <%= if @reading_mode == "double" && @current_page < @total_pages - 1 do %>
            <.double_page_view
              pages={@pages}
              current_page={@current_page}
              reading_mode={@reading_mode}
            />
          <% else %>
            <.single_page_view
              pages={@pages}
              current_page={@current_page}
              reading_mode={@reading_mode}
            />
          <% end %>
        </div>
      </div>

      <.progress_bar current_page={@current_page} total_pages={@total_pages} />
    </div>
    """
  end

  @doc """
  Renders the progress bar at the bottom of the reader.
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true

  def progress_bar(assigns) do
    ~H"""
    <div class="bg-gray-800 px-6 py-2 flex-shrink-0">
      <div class="w-full bg-gray-700 rounded-full h-1">
        <div
          class="bg-blue-600 h-1 rounded-full transition-all duration-300"
          style={"width: #{(@current_page + 1) / @total_pages * 100}%"}
        >
        </div>
      </div>
      <div class="flex justify-between text-xs text-gray-400 mt-1">
        <span>Start</span>
        <span>{@current_page + 1} / {@total_pages}</span>
        <span>End</span>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 100MB)"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
