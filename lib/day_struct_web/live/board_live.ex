defmodule DayStructWeb.BoardLive do
  use DayStructWeb, :live_view

  alias DayStruct.Store

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Store.subscribe()

    state = Store.get_state()
    areas = Enum.sort_by(state.areas, & &1.position)

    {:ok,
     socket
     |> assign(:page_title, "Board")
     |> assign(:active_tab, :board)
     |> assign(:areas, areas)
     |> assign(:tasks, state.tasks)
     |> assign(:inbox_count, length(state.inbox_items))}
  end

  @impl true
  def handle_event("quick_capture", %{"text" => text}, socket) when text != "" do
    {:ok, _} = DayStruct.Store.capture(String.trim(text))
    {:noreply, put_flash(socket, :info, "Captured!")}
  end

  def handle_event("quick_capture", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:state_updated, state}, socket) do
    areas = Enum.sort_by(state.areas, & &1.position)

    {:noreply,
     socket
     |> assign(:areas, areas)
     |> assign(:tasks, state.tasks)
     |> assign(:inbox_count, length(state.inbox_items))}
  end

  defp tasks_for_area(tasks, area_id) do
    Enum.filter(tasks, &(&1.area_id == area_id))
  end

  defp count_by_status(tasks, status) do
    Enum.count(tasks, &(&1.status == status))
  end

  defp area_color_class(color) do
    case color do
      "blue" -> "border-blue-400 bg-blue-50 dark:bg-blue-950/30"
      "green" -> "border-green-400 bg-green-50 dark:bg-green-950/30"
      "rose" -> "border-rose-400 bg-rose-50 dark:bg-rose-950/30"
      "amber" -> "border-amber-400 bg-amber-50 dark:bg-amber-950/30"
      _ -> "border-base-300 bg-base-100"
    end
  end

  defp area_badge_class(color) do
    case color do
      "blue" -> "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
      "green" -> "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
      "rose" -> "bg-rose-100 text-rose-800 dark:bg-rose-900 dark:text-rose-200"
      "amber" -> "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200"
      _ -> "bg-base-200 text-base-content"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <h1 class="text-2xl font-bold">Board</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <.link
          :for={area <- @areas}
          navigate={~p"/area/#{area.id}"}
          class={"card border-l-4 p-5 hover:shadow-md transition-shadow cursor-pointer #{area_color_class(area.color)}"}
        >
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold">{area.name}</h2>
            <span class={"text-xs font-medium px-2 py-1 rounded-full #{area_badge_class(area.color)}"}>
              {length(tasks_for_area(@tasks, area.id))} tasks
            </span>
          </div>
          <div class="flex gap-3 text-sm text-base-content/60">
            <span>{count_by_status(tasks_for_area(@tasks, area.id), "ready")} ready</span>
            <span>{count_by_status(tasks_for_area(@tasks, area.id), "active")} active</span>
            <span>{count_by_status(tasks_for_area(@tasks, area.id), "done")} done</span>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
