defmodule DayStructWeb.InboxLive do
  use DayStructWeb, :live_view

  alias DayStruct.Store
  alias DayStruct.BulkImport.Parser

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
     |> assign(:process_area_id, nil)
     |> assign(:bulk_mode, false)
     |> assign(:bulk_text, "")
     |> assign(:bulk_preview, [])}
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

  # Bulk import events

  def handle_event("toggle_bulk", _params, socket) do
    {:noreply,
     socket
     |> assign(:bulk_mode, !socket.assigns.bulk_mode)
     |> assign(:bulk_text, "")
     |> assign(:bulk_preview, [])}
  end

  def handle_event("bulk_parse", %{"bulk_text" => text}, socket) do
    preview = Parser.parse(text)
    {:noreply, socket |> assign(:bulk_text, text) |> assign(:bulk_preview, preview)}
  end

  def handle_event("bulk_toggle_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    preview =
      socket.assigns.bulk_preview
      |> Enum.with_index()
      |> Enum.map(fn {item, i} ->
        if i == index, do: %{item | selected: !item.selected}, else: item
      end)

    {:noreply, assign(socket, :bulk_preview, preview)}
  end

  def handle_event("bulk_import", _params, socket) do
    texts =
      socket.assigns.bulk_preview
      |> Enum.filter(& &1.selected)
      |> Enum.map(& &1.text)

    case texts do
      [] ->
        {:noreply, socket}

      texts ->
        {:ok, _items} = Store.bulk_capture(texts)
        count = length(texts)

        {:noreply,
         socket
         |> assign(:bulk_mode, false)
         |> assign(:bulk_text, "")
         |> assign(:bulk_preview, [])
         |> put_flash(:info, "Imported #{count} item#{if count != 1, do: "s"}")}
    end
  end

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
        <div class="flex gap-2">
          <button phx-click="toggle_bulk" class={"btn btn-sm #{if @bulk_mode, do: "btn-active", else: "btn-ghost"}"}>
            <.icon name="hero-document-text" class="size-4" /> Bulk Import
          </button>
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Board
          </.link>
        </div>
      </div>

      <%!-- Bulk import section --%>
      <div :if={@bulk_mode} class="card bg-base-200 p-4 space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="font-semibold">Bulk Import</h2>
          <button phx-click="toggle_bulk" class="btn btn-ghost btn-xs">
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>

        <form phx-change="bulk_parse">
          <textarea
            name="bulk_text"
            value={@bulk_text}
            placeholder="Paste Logseq journal entries here..."
            class="textarea textarea-bordered w-full h-40 font-mono text-sm"
            phx-debounce="300"
          />
        </form>

        <div :if={@bulk_preview != []} class="space-y-3">
          <div class="text-sm text-base-content/60">
            {Enum.count(@bulk_preview, & &1.selected)} of {length(@bulk_preview)} items selected
          </div>

          <div class="space-y-1 max-h-64 overflow-y-auto">
            <label
              :for={{item, index} <- Enum.with_index(@bulk_preview)}
              class="flex items-start gap-2 p-2 rounded hover:bg-base-300 cursor-pointer"
            >
              <input
                type="checkbox"
                checked={item.selected}
                phx-click="bulk_toggle_item"
                phx-value-index={index}
                class="checkbox checkbox-sm mt-0.5"
              />
              <span class={"text-sm whitespace-pre-wrap #{unless item.selected, do: "line-through opacity-40"}"}>
                {item.text}
              </span>
            </label>
          </div>

          <button
            phx-click="bulk_import"
            class="btn btn-primary btn-sm"
            disabled={Enum.count(@bulk_preview, & &1.selected) == 0}
          >
            Import {Enum.count(@bulk_preview, & &1.selected)} items
          </button>
        </div>
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
            <p class="font-medium whitespace-pre-wrap">{item.text}</p>
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
