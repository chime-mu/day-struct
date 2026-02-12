defmodule DayStructWeb.DayPlanLive do
  use DayStructWeb, :live_view

  alias DayStruct.Store
  alias DayStruct.Models.{Task, TimeBlock}

  @day_start 360
  @day_end 1320
  @pixels_per_minute 1.5

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket), do: Store.subscribe()

    date =
      case params["date"] do
        nil -> Date.utc_today() |> Date.to_iso8601()
        d -> d
      end

    state = Store.get_state()
    plan = Map.get(state.day_plans, date, %DayStruct.Models.DayPlan{date: date, blocks: []})
    scheduled_task_ids = Enum.map(plan.blocks, & &1.task_id) |> MapSet.new()

    available_tasks =
      state.tasks
      |> Enum.filter(fn t ->
        Task.schedulable?(t, state.tasks) and not MapSet.member?(scheduled_task_ids, t.id)
      end)

    areas = Enum.sort_by(state.areas, & &1.position)
    areas_map = Map.new(areas, &{&1.id, &1})

    now_minute = now_minute_of_day()

    socket =
      socket
      |> assign(:page_title, "Day Plan — #{date}")
      |> assign(:date, date)
      |> assign(:plan, plan)
      |> assign(:all_tasks, state.tasks)
      |> assign(:available_tasks, available_tasks)
      |> assign(:areas, areas)
      |> assign(:areas_map, areas_map)
      |> assign(:day_start, @day_start)
      |> assign(:day_end, @day_end)
      |> assign(:pixels_per_minute, @pixels_per_minute)
      |> assign(:now_minute, now_minute)

    if connected?(socket) and is_today?(date) do
      :timer.send_interval(60_000, self(), :tick)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "schedule_task",
        %{"task_id" => task_id, "start_minute" => start_minute},
        socket
      ) do
    start = if is_binary(start_minute), do: String.to_integer(start_minute), else: start_minute

    {:ok, _block} =
      Store.add_time_block(socket.assigns.date,
        task_id: task_id,
        start_minute: start,
        duration_minutes: 60
      )

    {:noreply, socket}
  end

  def handle_event(
        "move_block",
        %{"block_id" => block_id, "start_minute" => start_minute},
        socket
      ) do
    start = if is_binary(start_minute), do: String.to_integer(start_minute), else: start_minute
    Store.update_time_block(socket.assigns.date, block_id, start_minute: start)
    {:noreply, socket}
  end

  def handle_event(
        "resize_block",
        %{"block_id" => block_id, "duration_minutes" => duration},
        socket
      ) do
    dur = if is_binary(duration), do: String.to_integer(duration), else: duration
    dur = max(dur, 15)
    Store.update_time_block(socket.assigns.date, block_id, duration_minutes: dur)
    {:noreply, socket}
  end

  def handle_event("complete_block", %{"block_id" => block_id}, socket) do
    Store.complete_time_block(socket.assigns.date, block_id)
    {:noreply, socket}
  end

  def handle_event("remove_block", %{"block_id" => block_id}, socket) do
    Store.remove_time_block(socket.assigns.date, block_id)
    {:noreply, socket}
  end

  def handle_event("prev_day", _params, socket) do
    date = Date.from_iso8601!(socket.assigns.date) |> Date.add(-1) |> Date.to_iso8601()
    {:noreply, push_navigate(socket, to: ~p"/day/#{date}")}
  end

  def handle_event("next_day", _params, socket) do
    date = Date.from_iso8601!(socket.assigns.date) |> Date.add(1) |> Date.to_iso8601()
    {:noreply, push_navigate(socket, to: ~p"/day/#{date}")}
  end

  def handle_event("quick_capture", %{"text" => text}, socket) when text != "" do
    {:ok, _} = DayStruct.Store.capture(String.trim(text))
    {:noreply, put_flash(socket, :info, "Captured!")}
  end

  def handle_event("quick_capture", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:state_updated, state}, socket) do
    date = socket.assigns.date
    plan = Map.get(state.day_plans, date, %DayStruct.Models.DayPlan{date: date, blocks: []})
    scheduled_task_ids = Enum.map(plan.blocks, & &1.task_id) |> MapSet.new()

    available_tasks =
      state.tasks
      |> Enum.filter(fn t ->
        Task.schedulable?(t, state.tasks) and not MapSet.member?(scheduled_task_ids, t.id)
      end)

    areas_map = Map.new(state.areas, &{&1.id, &1})

    {:noreply,
     socket
     |> assign(:plan, plan)
     |> assign(:all_tasks, state.tasks)
     |> assign(:available_tasks, available_tasks)
     |> assign(:areas_map, areas_map)}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :now_minute, now_minute_of_day())}
  end

  defp task_for_block(block, all_tasks) do
    Enum.find(all_tasks, &(&1.id == block.task_id))
  end

  defp area_for_task(task, areas_map) when not is_nil(task) do
    Map.get(areas_map, task.area_id)
  end

  defp area_for_task(_, _), do: nil

  defp block_color(block, all_tasks, areas_map) do
    task = task_for_block(block, all_tasks)
    area = area_for_task(task, areas_map)

    cond do
      block.completed ->
        "bg-green-100 border-green-400 dark:bg-green-950/40 dark:border-green-600"

      area && area.color == "blue" ->
        "bg-blue-100 border-blue-400 dark:bg-blue-950/40 dark:border-blue-600"

      area && area.color == "green" ->
        "bg-green-100 border-green-400 dark:bg-green-950/40 dark:border-green-600"

      area && area.color == "rose" ->
        "bg-rose-100 border-rose-400 dark:bg-rose-950/40 dark:border-rose-600"

      area && area.color == "amber" ->
        "bg-amber-100 border-amber-400 dark:bg-amber-950/40 dark:border-amber-600"

      true ->
        "bg-base-200 border-base-300"
    end
  end

  defp sidebar_area_color(color) do
    case color do
      "blue" -> "border-l-blue-400"
      "green" -> "border-l-green-400"
      "rose" -> "border-l-rose-400"
      "amber" -> "border-l-amber-400"
      _ -> "border-l-base-300"
    end
  end

  defp timeline_height(day_start, day_end, ppm) do
    (day_end - day_start) * ppm
  end

  defp hour_marks(day_start, day_end) do
    start_hour = div(day_start, 60)
    end_hour = div(day_end, 60)
    for h <- start_hour..end_hour, do: h * 60
  end

  defp half_hour_marks(day_start, day_end) do
    start_hour = div(day_start, 60)
    end_hour = div(day_end, 60)
    for h <- start_hour..(end_hour - 1), do: h * 60 + 30
  end

  defp format_hour(minutes) do
    TimeBlock.format_time(minutes)
  end

  defp is_today?(date) do
    date == Date.utc_today() |> Date.to_iso8601()
  end

  defp format_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> Calendar.strftime(date, "%A, %B %-d")
      _ -> date_str
    end
  end

  defp now_minute_of_day do
    now = Time.utc_now()
    now.hour * 60 + now.minute
  end

  defp show_now_line?(date, now_minute, day_start, day_end) do
    is_today?(date) and now_minute >= day_start and now_minute <= day_end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" />
          </.link>
          <h1 class="text-2xl font-bold">Day Plan</h1>
        </div>
        <div class="flex items-center gap-2">
          <button phx-click="prev_day" class="btn btn-ghost btn-sm">
            <.icon name="hero-chevron-left" class="size-4" />
          </button>
          <span class={"font-medium #{if is_today?(@date), do: "text-primary"}"}>
            {format_date(@date)}
          </span>
          <button phx-click="next_day" class="btn btn-ghost btn-sm">
            <.icon name="hero-chevron-right" class="size-4" />
          </button>
        </div>
      </div>

      <div class="flex gap-4" style="min-height: 70vh;">
        <%!-- Sidebar: available tasks --%>
        <div class="w-56 shrink-0 space-y-2">
          <h3 class="text-sm font-semibold text-base-content/60 uppercase tracking-wide">
            Available Tasks
          </h3>
          <div :if={@available_tasks == []} class="text-center py-8 space-y-3">
            <.icon name="hero-clipboard-document-list" class="size-10 mx-auto text-base-content/20" />
            <p class="text-sm text-base-content/40">No tasks to schedule</p>
            <p class="text-xs text-base-content/30">
              Create tasks on the
              <.link navigate={~p"/"} class="underline text-primary/60 hover:text-primary">
                Board
              </.link>
              first
            </p>
          </div>
          <div
            :for={task <- @available_tasks}
            id={"sidebar-task-#{task.id}"}
            draggable="true"
            data-task-id={task.id}
            class={[
              "sidebar-task cursor-grab active:cursor-grabbing",
              "rounded border-l-4 bg-base-100 border border-base-300 px-3 py-2 text-sm shadow-sm",
              "hover:shadow-md transition-shadow",
              sidebar_area_color(
                area_for_task(task, @areas_map) && area_for_task(task, @areas_map).color
              )
            ]}
          >
            <div class="font-medium truncate">{task.title}</div>
            <div class="text-xs text-base-content/50 mt-0.5">
              {area_for_task(task, @areas_map) && area_for_task(task, @areas_map).name}
            </div>
          </div>
        </div>

        <%!-- Timeline --%>
        <div
          id="timeline"
          phx-hook="Timeline"
          class="flex-1 relative border border-base-300 rounded-lg overflow-y-auto bg-base-100"
          data-day-start={@day_start}
          data-day-end={@day_end}
          data-ppm={@pixels_per_minute}
        >
          <div
            class="relative"
            style={"height: #{timeline_height(@day_start, @day_end, @pixels_per_minute)}px;"}
          >
            <%!-- Hour lines --%>
            <div
              :for={minute <- hour_marks(@day_start, @day_end)}
              class="absolute left-0 right-0 border-t border-base-200 flex items-start"
              style={"top: #{(minute - @day_start) * @pixels_per_minute}px;"}
            >
              <span class="text-xs font-medium tabular-nums text-base-content/50 px-2 -translate-y-1/2 bg-base-100 select-none">
                {format_hour(minute)}
              </span>
            </div>

            <%!-- Half-hour dashed lines --%>
            <div
              :for={minute <- half_hour_marks(@day_start, @day_end)}
              class="absolute left-12 right-0 border-t border-dashed border-base-200/60"
              style={"top: #{(minute - @day_start) * @pixels_per_minute}px;"}
            >
            </div>

            <%!-- "Now" indicator line --%>
            <div
              :if={show_now_line?(@date, @now_minute, @day_start, @day_end)}
              class="absolute left-0 right-0 z-20 flex items-center pointer-events-none"
              style={"top: #{(@now_minute - @day_start) * @pixels_per_minute}px;"}
            >
              <div class="w-2.5 h-2.5 rounded-full bg-red-500 -ml-1 shrink-0"></div>
              <div class="flex-1 border-t-2 border-red-500"></div>
            </div>

            <%!-- Empty state overlay --%>
            <div
              :if={@plan.blocks == []}
              class="absolute inset-0 flex items-center justify-center pointer-events-none z-10"
            >
              <div class="text-center space-y-3 p-6 rounded-xl bg-base-100/80 backdrop-blur-sm">
                <.icon name="hero-calendar-days" class="size-12 mx-auto text-base-content/20" />
                <p class="text-base-content/50 font-medium">No blocks scheduled yet</p>
                <p class="text-xs text-base-content/30 max-w-48">
                  Drag tasks from the sidebar to schedule them on the timeline
                </p>
              </div>
            </div>

            <%!-- Time blocks --%>
            <div
              :for={block <- @plan.blocks}
              id={"block-#{block.id}"}
              data-block-id={block.id}
              data-start-minute={block.start_minute}
              data-duration-minutes={block.duration_minutes}
              class={[
                "time-block absolute left-12 right-2 rounded border-l-4 px-3 py-1 cursor-grab active:cursor-grabbing",
                "group flex flex-col justify-between",
                block_color(block, @all_tasks, @areas_map),
                block.completed && "opacity-60"
              ]}
              style={"top: #{(block.start_minute - @day_start) * @pixels_per_minute}px; height: #{block.duration_minutes * @pixels_per_minute}px; min-height: 24px;"}
            >
              <div class="flex items-start justify-between gap-1 min-h-0">
                <div class="truncate">
                  <div class="font-medium text-sm truncate">
                    {(task_for_block(block, @all_tasks) && task_for_block(block, @all_tasks).title) ||
                      "Unknown task"}
                  </div>
                  <div class="text-xs text-base-content/50">
                    {TimeBlock.format_time(block.start_minute)} - {TimeBlock.format_time(
                      TimeBlock.end_minute(block)
                    )}
                  </div>
                </div>
                <div class="flex gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                  <button
                    :if={!block.completed}
                    phx-click="complete_block"
                    phx-value-block_id={block.id}
                    class="btn btn-xs btn-ghost text-success"
                    title="Complete"
                  >
                    <.icon name="hero-check" class="size-3" />
                  </button>
                  <button
                    phx-click="remove_block"
                    phx-value-block_id={block.id}
                    class="btn btn-xs btn-ghost text-error"
                    title="Remove"
                  >
                    <.icon name="hero-x-mark" class="size-3" />
                  </button>
                </div>
              </div>

              <%!-- Resize handle --%>
              <div
                :if={!block.completed}
                class="resize-handle absolute bottom-0 left-0 right-0 h-2 cursor-ns-resize hover:bg-base-content/10 rounded-b"
                data-block-id={block.id}
              >
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
