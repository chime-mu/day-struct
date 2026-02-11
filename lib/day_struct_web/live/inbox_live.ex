defmodule DayStructWeb.InboxLive do
  use DayStructWeb, :live_view

  alias DayStruct.Store

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Store.subscribe()

    areas = Store.get_areas()
    items = Store.get_inbox_items()

    {:ok,
     socket
     |> assign(:page_title, "Inbox")
     |> assign(:areas, areas)
     |> assign(:items, items)
     |> assign(:capture_text, "")
     |> assign(:processing_item, nil)
     |> assign(:process_title, "")
     |> assign(:process_area_id, nil)}
  end

  @impl true
  def handle_event("capture", %{"text" => text}, socket) when text != "" do
    {:ok, _item} = Store.capture(String.trim(text))
    {:noreply, assign(socket, :capture_text, "")}
  end

  def handle_event("capture", _params, socket), do: {:noreply, socket}

  def handle_event("start_process", %{"id" => item_id}, socket) do
    item = Enum.find(socket.assigns.items, &(&1.id == item_id))

    {:noreply,
     socket
     |> assign(:processing_item, item)
     |> assign(:process_title, item.text)
     |> assign(:process_area_id, List.first(socket.assigns.areas) && List.first(socket.assigns.areas).id)}
  end

  def handle_event("cancel_process", _params, socket) do
    {:noreply,
     socket
     |> assign(:processing_item, nil)
     |> assign(:process_title, "")
     |> assign(:process_area_id, nil)}
  end

  def handle_event("process", %{"title" => title, "area_id" => area_id}, socket) do
    item = socket.assigns.processing_item

    if item && title != "" && area_id != "" do
      {:ok, _task} = Store.process_inbox_item(item.id, area_id, String.trim(title))

      {:noreply,
       socket
       |> assign(:processing_item, nil)
       |> assign(:process_title, "")
       |> assign(:process_area_id, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("discard", %{"id" => item_id}, socket) do
    Store.discard_inbox_item(item_id)
    {:noreply, socket}
  end

  def handle_event("quick_capture", %{"text" => text}, socket) when text != "" do
    {:ok, _} = DayStruct.Store.capture(String.trim(text))
    {:noreply, put_flash(socket, :info, "Captured!")}
  end

  def handle_event("quick_capture", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply,
     socket
     |> assign(:items, state.inbox_items)
     |> assign(:areas, Enum.sort_by(state.areas, & &1.position))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Inbox</h1>
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Board
        </.link>
      </div>

      <%!-- Capture form --%>
      <form phx-submit="capture" class="flex gap-2">
        <input
          type="text"
          name="text"
          value={@capture_text}
          placeholder="Capture a thought..."
          class="input input-bordered flex-1"
          autofocus
          phx-hook="AutoFocus"
          id="inbox-capture"
        />
        <button type="submit" class="btn btn-primary">
          <.icon name="hero-plus" class="size-4" /> Capture
        </button>
      </form>

      <%!-- Processing modal --%>
      <div :if={@processing_item} class="card bg-base-200 p-4 space-y-3">
        <div class="text-sm text-base-content/60">Processing: "{@processing_item.text}"</div>
        <form phx-submit="process" class="space-y-3">
          <input
            type="text"
            name="title"
            value={@process_title}
            placeholder="Task title"
            class="input input-bordered w-full"
            autofocus
          />
          <select name="area_id" class="select select-bordered w-full">
            <option :for={area <- @areas} value={area.id} selected={area.id == @process_area_id}>
              {area.name}
            </option>
          </select>
          <div class="flex gap-2">
            <button type="submit" class="btn btn-primary btn-sm">Create Task</button>
            <button type="button" phx-click="cancel_process" class="btn btn-ghost btn-sm">
              Cancel
            </button>
          </div>
        </form>
      </div>

      <%!-- Items list --%>
      <div :if={@items == []} class="text-center py-12 text-base-content/40">
        <.icon name="hero-inbox" class="size-12 mx-auto mb-3" />
        <p>Inbox is empty. Capture something above or press Cmd+K anywhere.</p>
      </div>

      <div class="space-y-2">
        <div
          :for={item <- @items}
          class="card bg-base-100 border border-base-300 p-3 flex flex-row items-center justify-between gap-3"
        >
          <div class="flex-1">
            <p class="font-medium">{item.text}</p>
            <p class="text-xs text-base-content/40">{format_time(item.created_at)}</p>
          </div>
          <div class="flex gap-1">
            <button
              phx-click="start_process"
              phx-value-id={item.id}
              class="btn btn-sm btn-primary btn-outline"
            >
              Process
            </button>
            <button
              phx-click="discard"
              phx-value-id={item.id}
              class="btn btn-sm btn-ghost text-error"
              data-confirm="Discard this item?"
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_time(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M")
      _ -> ""
    end
  end
end
