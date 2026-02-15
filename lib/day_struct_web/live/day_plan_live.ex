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

    tz_offset =
      if connected?(socket) do
        get_connect_params(socket)["tz_offset"] || 0
      else
        0
      end

    date =
      case params["date"] do
        nil -> local_today(tz_offset)
        d -> d
      end

    state = Store.get_state()
    plan = Map.get(state.day_plans, date, %DayStruct.Models.DayPlan{date: date, blocks: []})
    scheduled_task_ids = Enum.flat_map(plan.blocks, & &1.task_ids) |> MapSet.new()

    available_tasks =
      state.tasks
      |> Enum.filter(fn t ->
        Task.schedulable?(t, state.tasks) and not MapSet.member?(scheduled_task_ids, t.id)
      end)

    areas = Enum.sort_by(state.areas, & &1.position)
    areas_map = Map.new(areas, &{&1.id, &1})

    now_minute = now_minute_of_day(tz_offset)

    socket =
      socket
      |> assign(:page_title, "Day Plan — #{date}")
      |> assign(:active_tab, :today)
      |> assign(:date, date)
      |> assign(:plan, plan)
      |> assign(:all_tasks, state.tasks)
      |> assign(:available_tasks, available_tasks)
      |> assign(:areas, areas)
      |> assign(:areas_map, areas_map)
      |> assign(:inbox_count, length(state.inbox_items))
      |> assign(:day_start, @day_start)
      |> assign(:day_end, @day_end)
      |> assign(:pixels_per_minute, @pixels_per_minute)
      |> assign(:now_minute, now_minute)
      |> assign(:tz_offset, tz_offset)

    if connected?(socket) and is_today?(date, tz_offset) do
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

  def handle_event(
        "add_task_to_block",
        %{"block_id" => block_id, "task_id" => task_id},
        socket
      ) do
    Store.add_task_to_block(socket.assigns.date, block_id, task_id)
    {:noreply, socket}
  end

  def handle_event(
        "remove_task_from_block",
        %{"block_id" => block_id, "task_id" => task_id},
        socket
      ) do
    Store.remove_task_from_block(socket.assigns.date, block_id, task_id)
    {:noreply, socket}
  end

  def handle_event(
        "complete_task_in_block",
        %{"block_id" => block_id, "task_id" => task_id},
        socket
      ) do
    Store.complete_task_in_block(socket.assigns.date, block_id, task_id)
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
    scheduled_task_ids = Enum.flat_map(plan.blocks, & &1.task_ids) |> MapSet.new()

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
     |> assign(:areas, Enum.sort_by(state.areas, & &1.position))
     |> assign(:areas_map, areas_map)
     |> assign(:inbox_count, length(state.inbox_items))}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :now_minute, now_minute_of_day(socket.assigns.tz_offset))}
  end

  defp task_for_block(block, all_tasks) do
    Enum.find(all_tasks, &(&1.id == hd(block.task_ids)))
  end

  defp find_task(task_id, all_tasks) do
    Enum.find(all_tasks, &(&1.id == task_id))
  end

  defp area_for_task(task, areas_map) when not is_nil(task) do
    Map.get(areas_map, task.area_id)
  end

  defp area_for_task(_, _), do: nil

  defp block_color(block, all_tasks, areas_map) do
    if length(block.task_ids) > 1 do
      multi_block_color(block)
    else
      single_block_color(block, all_tasks, areas_map)
    end
  end

  defp multi_block_color(block) do
    if TimeBlock.completed?(block) do
      "bg-green-100 border-green-400 dark:bg-green-950/40 dark:border-green-600"
    else
      "bg-base-200 border-base-300"
    end
  end

  defp single_block_color(block, all_tasks, areas_map) do
    task = task_for_block(block, all_tasks)
    area = area_for_task(task, areas_map)

    cond do
      TimeBlock.completed?(block) ->
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

  defp area_dot_color(color) do
    case color do
      "blue" -> "bg-blue-400"
      "green" -> "bg-green-400"
      "rose" -> "bg-rose-400"
      "amber" -> "bg-amber-400"
      _ -> "bg-base-400"
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

  defp is_today?(date, tz_offset) do
    date == local_today(tz_offset)
  end

  defp format_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> Calendar.strftime(date, "%A, %B %-d")
      _ -> date_str
    end
  end

  defp local_today(tz_offset) do
    DateTime.utc_now() |> DateTime.add(tz_offset * 60) |> DateTime.to_date() |> Date.to_iso8601()
  end

  defp now_minute_of_day(tz_offset) do
    now = Time.utc_now()
    utc_minutes = now.hour * 60 + now.minute
    rem(utc_minutes + tz_offset + 1440, 1440)
  end

  defp show_now_line?(date, now_minute, day_start, day_end, tz_offset) do
    is_today?(date, tz_offset) and now_minute >= day_start and now_minute <= day_end
  end

  defp visible_task_ids(block, block_height) do
    # Estimate row height: ~28px per task row, ~24px for header
    available = block_height - 24
    max_rows = max(trunc(available / 28), 1)

    if length(block.task_ids) <= max_rows do
      {block.task_ids, 0}
    else
      visible = Enum.take(block.task_ids, max_rows)
      overflow = length(block.task_ids) - max_rows
      {visible, overflow}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Day Plan</h1>
        <div class="flex items-center gap-2">
          <button phx-click="prev_day" class="btn btn-ghost btn-sm">
            <.icon name="hero-chevron-left" class="size-4" />
          </button>
          <span class={"font-medium #{if is_today?(@date, @tz_offset), do: "text-primary"}"}>
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
            <.link
              :if={area_for_task(task, @areas_map)}
              navigate={~p"/area/#{area_for_task(task, @areas_map).id}"}
              class="text-xs text-base-content/50 mt-0.5 hover:text-primary hover:underline"
            >
              {area_for_task(task, @areas_map).name}
            </.link>
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
              :if={show_now_line?(@date, @now_minute, @day_start, @day_end, @tz_offset)}
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
            <%= for block <- @plan.blocks do %>
              <% block_height = block.duration_minutes * @pixels_per_minute %>
              <div
                id={"block-#{block.id}"}
                data-block-id={block.id}
                data-start-minute={block.start_minute}
                data-duration-minutes={block.duration_minutes}
                class={[
                  "time-block absolute left-12 right-2 rounded border-l-4 px-3 py-1 cursor-grab active:cursor-grabbing",
                  "group flex flex-col",
                  block_color(block, @all_tasks, @areas_map),
                  TimeBlock.completed?(block) && "opacity-60"
                ]}
                style={"top: #{(block.start_minute - @day_start) * @pixels_per_minute}px; height: #{block_height}px; min-height: 24px;"}
              >
                <%= if length(block.task_ids) == 1 do %>
                  <%!-- Single-task block (unchanged layout) --%>
                  <div class="flex items-start justify-between gap-1 min-h-0 flex-1">
                    <div class="truncate">
                      <div class="font-medium text-sm truncate">
                        {(task_for_block(block, @all_tasks) &&
                            task_for_block(block, @all_tasks).title) ||
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
                        :if={!TimeBlock.completed?(block)}
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
                <% else %>
                  <%!-- Multi-task block --%>
                  <% {visible_ids, overflow} = visible_task_ids(block, block_height) %>
                  <%!-- Block header --%>
                  <div class="flex items-center justify-between gap-1 mb-0.5">
                    <div class="text-xs text-base-content/50 font-medium">
                      {TimeBlock.format_time(block.start_minute)} - {TimeBlock.format_time(
                        TimeBlock.end_minute(block)
                      )}
                    </div>
                    <div class="flex gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                      <button
                        phx-click="remove_block"
                        phx-value-block_id={block.id}
                        class="btn btn-xs btn-ghost text-error"
                        title="Remove all"
                      >
                        <.icon name="hero-x-mark" class="size-3" />
                      </button>
                    </div>
                  </div>
                  <%!-- Task rows --%>
                  <div class="flex-1 min-h-0 overflow-hidden space-y-px">
                    <div
                      :for={task_id <- visible_ids}
                      class={[
                        "flex items-center gap-1.5 text-sm py-0.5",
                        task_id in block.completed_task_ids && "opacity-50"
                      ]}
                    >
                      <% task = find_task(task_id, @all_tasks) %>
                      <% area = task && area_for_task(task, @areas_map) %>
                      <div class={"w-2 h-2 rounded-full shrink-0 #{area_dot_color(area && area.color)}"}>
                      </div>
                      <button
                        :if={task_id not in block.completed_task_ids}
                        phx-click="complete_task_in_block"
                        phx-value-block_id={block.id}
                        phx-value-task_id={task_id}
                        class="btn btn-xs btn-ghost btn-circle text-success p-0 min-h-0 h-4 w-4 shrink-0"
                        title="Complete task"
                      >
                        <.icon name="hero-check" class="size-2.5" />
                      </button>
                      <span
                        :if={task_id in block.completed_task_ids}
                        class="inline-flex items-center justify-center h-4 w-4 shrink-0 text-success/50"
                      >
                        <.icon name="hero-check" class="size-2.5" />
                      </span>
                      <span class={[
                        "truncate flex-1 text-xs",
                        task_id in block.completed_task_ids && "line-through"
                      ]}>
                        {(task && task.title) || "Unknown task"}
                      </span>
                      <button
                        phx-click="remove_task_from_block"
                        phx-value-block_id={block.id}
                        phx-value-task_id={task_id}
                        class="btn btn-xs btn-ghost btn-circle text-error p-0 min-h-0 h-4 w-4 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
                        title="Remove from block"
                      >
                        <.icon name="hero-x-mark" class="size-2.5" />
                      </button>
                    </div>
                    <div :if={overflow > 0} class="text-xs text-base-content/40 pl-3.5">
                      +{overflow} more
                    </div>
                  </div>
                <% end %>

                <%!-- Resize handle --%>
                <div
                  :if={!TimeBlock.completed?(block)}
                  class="resize-handle absolute bottom-0 left-0 right-0 h-2 cursor-ns-resize hover:bg-base-content/10 rounded-b"
                  data-block-id={block.id}
                >
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
