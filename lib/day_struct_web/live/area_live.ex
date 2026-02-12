defmodule DayStructWeb.AreaLive do
  use DayStructWeb, :live_view

  alias DayStruct.Store
  alias DayStruct.Models.Task

  @impl true
  def mount(%{"id" => area_id}, _session, socket) do
    if connected?(socket), do: Store.subscribe()

    state = Store.get_state()
    area = Enum.find(state.areas, &(&1.id == area_id))

    if area do
      tasks = Enum.filter(state.tasks, &(&1.area_id == area_id))
      all_tasks = state.tasks
      projects = Enum.filter(state.projects, &(&1.area_id == area_id && &1.status == "active"))

      {:ok,
       socket
       |> assign(:page_title, area.name)
       |> assign(:area, area)
       |> assign(:tasks, tasks)
       |> assign(:all_tasks, all_tasks)
       |> assign(:projects, projects)
       |> assign(:editing_task, nil)
       |> assign(:new_task_title, "")
       |> assign(:show_done, false)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Area not found")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("move_task", %{"id" => id, "x" => x, "y" => y}, socket) do
    Store.move_task(id, x, y)
    {:noreply, socket}
  end

  def handle_event("create_task", %{"title" => title}, socket) when title != "" do
    x = Float.round(0.55 + :rand.uniform() * 0.40, 4)
    y = Float.round(0.55 + :rand.uniform() * 0.40, 4)

    {:ok, _task} =
      Store.create_task(
        title: String.trim(title),
        area_id: socket.assigns.area.id,
        status: "ready",
        x: x,
        y: y
      )

    {:noreply, assign(socket, :new_task_title, "")}
  end

  def handle_event("create_task", _params, socket), do: {:noreply, socket}

  def handle_event("edit_task", %{"id" => id}, socket) do
    task = Enum.find(socket.assigns.tasks, &(&1.id == id))
    {:noreply, assign(socket, :editing_task, task)}
  end

  def handle_event("close_edit", _params, socket) do
    {:noreply, assign(socket, :editing_task, nil)}
  end

  def handle_event("save_task", params, socket) do
    task = socket.assigns.editing_task

    if task do
      depends_on =
        (params["depends_on"] || [])
        |> List.wrap()
        |> Enum.reject(&(&1 == ""))

      project_id =
        case params["project_id"] do
          "" -> nil
          id -> id
        end

      {:ok, _updated} =
        Store.update_task(task.id,
          title: params["title"],
          description: params["description"],
          status: params["status"],
          depends_on: depends_on,
          project_id: project_id
        )

      {:noreply, assign(socket, :editing_task, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_task", %{"id" => id}, socket) do
    Store.delete_task(id)
    {:noreply, assign(socket, :editing_task, nil)}
  end

  def handle_event("toggle_done", _params, socket) do
    {:noreply, assign(socket, :show_done, !socket.assigns.show_done)}
  end

  def handle_event("quick_capture", %{"text" => text}, socket) when text != "" do
    {:ok, _} = DayStruct.Store.capture(String.trim(text))
    {:noreply, put_flash(socket, :info, "Captured!")}
  end

  def handle_event("quick_capture", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:state_updated, state}, socket) do
    area_id = socket.assigns.area.id
    tasks = Enum.filter(state.tasks, &(&1.area_id == area_id))
    projects = Enum.filter(state.projects, &(&1.area_id == area_id && &1.status == "active"))

    editing =
      if socket.assigns.editing_task do
        Enum.find(state.tasks, &(&1.id == socket.assigns.editing_task.id))
      end

    {:noreply,
     socket
     |> assign(:tasks, tasks)
     |> assign(:all_tasks, state.tasks)
     |> assign(:projects, projects)
     |> assign(:editing_task, editing)}
  end

  defp visible_tasks(tasks, show_done) do
    if show_done do
      tasks
    else
      Enum.reject(tasks, &(&1.status in ["done", "dropped"]))
    end
  end

  defp status_label("ready"), do: "Ready"
  defp status_label("active"), do: "Active"
  defp status_label("done"), do: "Done"
  defp status_label("dropped"), do: "Dropped"
  defp status_label(_), do: "Unknown"

  defp status_color("ready"), do: "badge-info"
  defp status_color("active"), do: "badge-warning"
  defp status_color("done"), do: "badge-success"
  defp status_color("dropped"), do: "badge-ghost"
  defp status_color(_), do: "badge-ghost"

  defp area_border_color(color) do
    case color do
      "blue" -> "border-blue-400"
      "green" -> "border-green-400"
      "rose" -> "border-rose-400"
      "amber" -> "border-amber-400"
      _ -> "border-base-300"
    end
  end

  defp other_tasks_for_deps(_all_tasks, _current_task_id, nil), do: []

  defp other_tasks_for_deps(all_tasks, current_task_id, project_id) do
    all_tasks
    |> Enum.filter(
      &(&1.id != current_task_id && &1.status not in ["done", "dropped"] &&
          &1.project_id == project_id)
    )
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
          <h1 class="text-2xl font-bold">{@area.name}</h1>
        </div>
        <div class="flex gap-2">
          <label class="label cursor-pointer gap-2">
            <span class="text-sm">Show done</span>
            <input
              type="checkbox"
              class="toggle toggle-sm"
              checked={@show_done}
              phx-click="toggle_done"
            />
          </label>
        </div>
      </div>

      <%!-- New task input --%>
      <form phx-submit="create_task" class="flex gap-2">
        <input
          type="text"
          name="title"
          value={@new_task_title}
          placeholder="New task..."
          class="input input-bordered flex-1 input-sm"
        />
        <button type="submit" class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" />
        </button>
      </form>

      <%!-- Spatial pane --%>
      <div
        id="spatial-pane"
        phx-hook="SpatialPane"
        class={"relative w-full border-2 rounded-lg overflow-hidden #{area_border_color(@area.color)}"}
        style="height: 60vh; min-height: 400px;"
      >
        <%!-- Priority hint --%>
        <div class="absolute inset-x-0 top-2 text-center text-xs text-base-content/20 pointer-events-none select-none">
          Higher priority
        </div>
        <div class="absolute inset-x-0 bottom-2 text-center text-xs text-base-content/20 pointer-events-none select-none">
          Lower priority
        </div>

        <div
          class="absolute inset-x-0 pointer-events-none flex items-center"
          style={"top: #{Task.today_line_y() * 100}%;"}
        >
          <div class="flex-1 border-t border-dashed border-base-content/15"></div>
          <span class="text-[10px] text-base-content/20 px-2 select-none uppercase tracking-widest">
            today
          </span>
          <div class="flex-1 border-t border-dashed border-base-content/15"></div>
        </div>

        <div
          class="absolute pointer-events-none border border-base-content/10 rounded"
          style="left: 50%; top: 50%; width: 50%; height: 50%;"
        >
          <span class="absolute top-1 left-2 text-[10px] text-base-content/20 select-none uppercase tracking-widest">
            new tasks
          </span>
        </div>

        <div
          :for={task <- visible_tasks(@tasks, @show_done)}
          id={"task-#{task.id}"}
          data-task-id={task.id}
          data-x={task.x}
          data-y={task.y}
          class={[
            "task-card absolute cursor-grab active:cursor-grabbing select-none",
            "rounded-lg border bg-base-100 shadow-sm px-3 py-2 max-w-48 text-sm",
            "hover:shadow-md transition-shadow",
            Task.blocked?(task, @all_tasks) && "opacity-50 cursor-not-allowed",
            task.status == "done" && "opacity-40 line-through"
          ]}
          style={"left: #{task.x * 100}%; top: #{task.y * 100}%; transform: translate(-50%, -50%);"}
          phx-click="edit_task"
          phx-value-id={task.id}
        >
          <div class="font-medium truncate">{task.title}</div>
          <span class={"badge badge-xs mt-1 #{status_color(task.status)}"}>
            {status_label(task.status)}
          </span>
          <span :if={task.depends_on != []} class="badge badge-xs mt-1 badge-ghost">
            <.icon name="hero-link" class="size-3" /> {length(task.depends_on)}
          </span>
        </div>
      </div>

      <%!-- Task editor --%>
      <div :if={@editing_task} class="card bg-base-200 p-4 space-y-3">
        <div class="flex items-center justify-between">
          <h3 class="font-semibold">Edit Task</h3>
          <button phx-click="close_edit" class="btn btn-ghost btn-xs">
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
        <form phx-submit="save_task" class="space-y-3">
          <input
            type="text"
            name="title"
            value={@editing_task.title}
            class="input input-bordered w-full input-sm"
            placeholder="Title"
          />
          <textarea
            name="description"
            class="textarea textarea-bordered w-full textarea-sm"
            rows="2"
            placeholder="Description (optional)"
          >{@editing_task.description}</textarea>
          <select name="status" class="select select-bordered select-sm w-full">
            <option
              :for={s <- ["ready", "active", "done", "dropped"]}
              value={s}
              selected={s == @editing_task.status}
            >
              {status_label(s)}
            </option>
          </select>

          <select name="project_id" class="select select-bordered select-sm w-full">
            <option value="" selected={is_nil(@editing_task.project_id)}>No project</option>
            <option
              :for={project <- @projects}
              value={project.id}
              selected={project.id == @editing_task.project_id}
            >
              {project.name}
            </option>
          </select>

          <%!-- Dependencies --%>
          <div class="space-y-1">
            <label class="label text-xs">Dependencies (select tasks this depends on)</label>
            <%= if is_nil(@editing_task.project_id) do %>
              <p class="text-xs text-base-content/50 italic">
                Assign a project to enable dependencies
              </p>
              <input type="hidden" name="depends_on[]" value="" />
            <% else %>
              <div class="flex flex-wrap gap-1">
                <label
                  :for={
                    t <- other_tasks_for_deps(@all_tasks, @editing_task.id, @editing_task.project_id)
                  }
                  class="flex items-center gap-1 text-xs bg-base-100 rounded px-2 py-1 cursor-pointer hover:bg-base-300"
                >
                  <input
                    type="checkbox"
                    name="depends_on[]"
                    value={t.id}
                    checked={t.id in (@editing_task.depends_on || [])}
                    class="checkbox checkbox-xs"
                  />
                  {t.title}
                </label>
              </div>
              <input type="hidden" name="depends_on[]" value="" />
            <% end %>
          </div>

          <div class="flex gap-2">
            <button type="submit" class="btn btn-primary btn-sm">Save</button>
            <button
              type="button"
              phx-click="delete_task"
              phx-value-id={@editing_task.id}
              class="btn btn-error btn-sm btn-outline"
              data-confirm="Delete this task?"
            >
              Delete
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
