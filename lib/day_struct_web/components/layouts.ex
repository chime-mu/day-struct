defmodule DayStructWeb.Layouts do
  use DayStructWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <header class="navbar bg-base-200 border-b border-base-300 px-4 sm:px-6">
        <div class="flex-1">
          <.link navigate={~p"/"} class="flex items-center gap-2 font-bold text-lg">
            <span class="text-primary">Day</span><span>Struct</span>
          </.link>
        </div>
        <nav class="flex-none">
          <ul class="flex items-center gap-1">
            <li>
              <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
                <.icon name="hero-squares-2x2" class="size-4" /> Board
              </.link>
            </li>
            <li>
              <.link navigate={~p"/inbox"} class="btn btn-ghost btn-sm">
                <.icon name="hero-inbox" class="size-4" /> Inbox
              </.link>
            </li>
            <li>
              <.link navigate={~p"/day"} class="btn btn-ghost btn-sm">
                <.icon name="hero-calendar" class="size-4" /> Today
              </.link>
            </li>
            <li>
              <.theme_toggle />
            </li>
          </ul>
        </nav>
      </header>

      <%!-- Quick capture modal (Cmd+K) --%>
      <div
        id="quick-capture"
        phx-hook="QuickCapture"
        class="hidden fixed inset-0 z-50 flex items-start justify-center pt-24 bg-black/40"
      >
        <div class="bg-base-100 rounded-lg shadow-2xl w-full max-w-lg p-4">
          <form phx-submit="quick_capture">
            <input
              type="text"
              name="text"
              placeholder="Capture a thought... (Esc to close)"
              class="input input-bordered w-full"
              autocomplete="off"
            />
          </form>
          <p class="text-xs text-base-content/40 mt-2">Press Enter to capture, Esc to close</p>
        </div>
      </div>

      <main class="px-4 py-6 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-6xl">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />
      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system">
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light">
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark">
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
