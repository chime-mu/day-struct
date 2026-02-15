defmodule DayStruct.Store do
  use GenServer

  alias DayStruct.Store.State
  alias DayStruct.Models.{Task, InboxItem, TimeBlock, DayPlan, Project}

  defp data_dir, do: Application.get_env(:day_struct, :store_data_dir, "data")
  defp state_file, do: Path.join(data_dir(), "state.json")
  defp backup_dir, do: Path.join(data_dir(), "backups")
  @debounce_ms 500
  @pubsub DayStruct.PubSub
  @topic "store:updates"

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)
  def get_areas, do: GenServer.call(__MODULE__, :get_areas)
  def get_tasks, do: GenServer.call(__MODULE__, :get_tasks)
  def get_tasks_for_area(area_id), do: GenServer.call(__MODULE__, {:get_tasks_for_area, area_id})
  def get_task(id), do: GenServer.call(__MODULE__, {:get_task, id})
  def get_inbox_items, do: GenServer.call(__MODULE__, :get_inbox_items)
  def get_day_plan(date), do: GenServer.call(__MODULE__, {:get_day_plan, date})

  def capture(text), do: GenServer.call(__MODULE__, {:capture, text})

  def bulk_capture(texts) when is_list(texts),
    do: GenServer.call(__MODULE__, {:bulk_capture, texts})

  def process_inbox_item(item_id, area_id, title, project_id \\ nil),
    do: GenServer.call(__MODULE__, {:process_inbox_item, item_id, area_id, title, project_id})

  def discard_inbox_item(item_id), do: GenServer.call(__MODULE__, {:discard_inbox_item, item_id})

  def create_task(attrs), do: GenServer.call(__MODULE__, {:create_task, attrs})
  def update_task(id, attrs), do: GenServer.call(__MODULE__, {:update_task, id, attrs})
  def move_task(id, x, y), do: GenServer.call(__MODULE__, {:move_task, id, x, y})
  def delete_task(id), do: GenServer.call(__MODULE__, {:delete_task, id})

  def get_projects, do: GenServer.call(__MODULE__, :get_projects)
  def create_project(attrs), do: GenServer.call(__MODULE__, {:create_project, attrs})
  def update_project(id, attrs), do: GenServer.call(__MODULE__, {:update_project, id, attrs})

  def add_time_block(date, attrs), do: GenServer.call(__MODULE__, {:add_time_block, date, attrs})

  def update_time_block(date, block_id, attrs),
    do: GenServer.call(__MODULE__, {:update_time_block, date, block_id, attrs})

  def remove_time_block(date, block_id),
    do: GenServer.call(__MODULE__, {:remove_time_block, date, block_id})

  def complete_time_block(date, block_id),
    do: GenServer.call(__MODULE__, {:complete_time_block, date, block_id})

  def add_task_to_block(date, block_id, task_id),
    do: GenServer.call(__MODULE__, {:add_task_to_block, date, block_id, task_id})

  def remove_task_from_block(date, block_id, task_id),
    do: GenServer.call(__MODULE__, {:remove_task_from_block, date, block_id, task_id})

  def complete_task_in_block(date, block_id, task_id),
    do: GenServer.call(__MODULE__, {:complete_task_in_block, date, block_id, task_id})

  def reset! do
    GenServer.call(__MODULE__, :reset)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    state = load_state()
    {:ok, %{state: state, save_timer: nil}}
  end

  @impl true
  def handle_call(:get_state, _from, %{state: state} = s) do
    {:reply, state, s}
  end

  def handle_call(:reset, _from, _s) do
    {:reply, :ok, %{state: State.new(), save_timer: nil}}
  end

  def handle_call(:get_areas, _from, %{state: state} = s) do
    {:reply, Enum.sort_by(state.areas, & &1.position), s}
  end

  def handle_call(:get_tasks, _from, %{state: state} = s) do
    {:reply, state.tasks, s}
  end

  def handle_call({:get_tasks_for_area, area_id}, _from, %{state: state} = s) do
    tasks = Enum.filter(state.tasks, &(&1.area_id == area_id))
    {:reply, tasks, s}
  end

  def handle_call({:get_task, id}, _from, %{state: state} = s) do
    {:reply, Enum.find(state.tasks, &(&1.id == id)), s}
  end

  def handle_call(:get_inbox_items, _from, %{state: state} = s) do
    {:reply, state.inbox_items, s}
  end

  def handle_call({:get_day_plan, date}, _from, %{state: state} = s) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))
    {:reply, plan, s}
  end

  def handle_call(:get_projects, _from, %{state: state} = s) do
    {:reply, state.projects, s}
  end

  def handle_call({:create_project, attrs}, _from, %{state: state} = s) do
    project = Project.new(attrs)
    new_state = %{state | projects: state.projects ++ [project]}
    {:reply, {:ok, project}, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:update_project, id, attrs}, _from, %{state: state} = s) do
    new_projects =
      Enum.map(state.projects, fn project ->
        if project.id == id do
          project
          |> maybe_put(:name, attrs[:name])
          |> maybe_put(:status, attrs[:status])
        else
          project
        end
      end)

    new_state = %{state | projects: new_projects}
    project = Enum.find(new_state.projects, &(&1.id == id))
    {:reply, {:ok, project}, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:capture, text}, _from, %{state: state} = s) do
    item = InboxItem.new(text: text)
    new_state = %{state | inbox_items: state.inbox_items ++ [item]}
    {:reply, {:ok, item}, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:bulk_capture, texts}, _from, %{state: state} = s) do
    items = Enum.map(texts, fn text -> InboxItem.new(text: text) end)
    new_state = %{state | inbox_items: state.inbox_items ++ items}
    {:reply, {:ok, items}, schedule_save(%{s | state: new_state})}
  end

  def handle_call(
        {:process_inbox_item, item_id, area_id, title, project_id},
        _from,
        %{state: state} = s
      ) do
    case Enum.find(state.inbox_items, &(&1.id == item_id)) do
      nil ->
        {:reply, {:error, :not_found}, s}

      _item ->
        task = Task.new(title: title, area_id: area_id, project_id: project_id, status: "ready")

        new_state = %{
          state
          | inbox_items: Enum.reject(state.inbox_items, &(&1.id == item_id)),
            tasks: state.tasks ++ [task]
        }

        {:reply, {:ok, task}, schedule_save(%{s | state: new_state})}
    end
  end

  def handle_call({:discard_inbox_item, item_id}, _from, %{state: state} = s) do
    new_state = %{state | inbox_items: Enum.reject(state.inbox_items, &(&1.id == item_id))}
    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:create_task, attrs}, _from, %{state: state} = s) do
    task = Task.new(attrs)
    new_state = %{state | tasks: state.tasks ++ [task]}
    {:reply, {:ok, task}, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:update_task, id, attrs}, _from, %{state: state} = s) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    old_task = Enum.find(state.tasks, &(&1.id == id))

    project_changing? =
      old_task && Keyword.has_key?(attrs, :project_id) &&
        attrs[:project_id] != old_task.project_id

    new_tasks =
      Enum.map(state.tasks, fn task ->
        if task.id == id do
          updated =
            task
            |> maybe_put(:title, attrs[:title])
            |> maybe_put(:description, attrs[:description])
            |> maybe_put(:area_id, attrs[:area_id])
            |> maybe_put(:status, attrs[:status])
            |> maybe_put(:depends_on, attrs[:depends_on])
            |> maybe_put_if_key(attrs, :project_id)
            |> maybe_put(:x, attrs[:x])
            |> maybe_put(:y, attrs[:y])
            |> Map.put(:updated_at, now)

          # Clear deps when project changes
          updated =
            if project_changing? do
              %{updated | depends_on: []}
            else
              updated
            end

          # Filter out cross-project dependencies
          validate_depends_on(updated, state.tasks)
        else
          task
        end
      end)

    # If project changed, remove this task from other tasks' depends_on lists
    new_tasks =
      if project_changing? do
        Enum.map(new_tasks, fn task ->
          if task.id != id && id in task.depends_on do
            %{task | depends_on: List.delete(task.depends_on, id)}
          else
            task
          end
        end)
      else
        new_tasks
      end

    new_state = %{state | tasks: new_tasks}
    task = Enum.find(new_state.tasks, &(&1.id == id))
    {:reply, {:ok, task}, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:move_task, id, x, y}, _from, %{state: state} = s) do
    new_tasks =
      Enum.map(state.tasks, fn task ->
        if task.id == id, do: %{task | x: x, y: y}, else: task
      end)

    new_state = %{state | tasks: new_tasks}
    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:delete_task, id}, _from, %{state: state} = s) do
    new_tasks = Enum.reject(state.tasks, &(&1.id == id))
    new_state = %{state | tasks: new_tasks}
    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:add_time_block, date, attrs}, _from, %{state: state} = s) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))
    block = TimeBlock.new(attrs)
    new_plan = %{plan | blocks: plan.blocks ++ [block]}
    new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}

    # Mark task(s) as active when scheduled
    new_state = Enum.reduce(block.task_ids, new_state, &mark_task_active(&2, &1))

    {:reply, {:ok, block}, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:update_time_block, date, block_id, attrs}, _from, %{state: state} = s) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))

    new_blocks =
      Enum.map(plan.blocks, fn block ->
        if block.id == block_id do
          block
          |> maybe_put(
            :start_minute,
            attrs[:start_minute] && TimeBlock.snap_to_grid(attrs[:start_minute])
          )
          |> maybe_put(
            :duration_minutes,
            attrs[:duration_minutes] && TimeBlock.snap_to_grid(attrs[:duration_minutes])
          )
        else
          block
        end
      end)

    new_plan = %{plan | blocks: new_blocks}
    new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}
    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:remove_time_block, date, block_id}, _from, %{state: state} = s) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))
    block = Enum.find(plan.blocks, &(&1.id == block_id))
    new_blocks = Enum.reject(plan.blocks, &(&1.id == block_id))
    new_plan = %{plan | blocks: new_blocks}
    new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}

    # Return each task to ready if removed from all schedules
    new_state =
      if block do
        Enum.reduce(block.task_ids, new_state, &revert_task_if_unscheduled(&2, &1))
      else
        new_state
      end

    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:complete_time_block, date, block_id}, _from, %{state: state} = s) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))
    block = Enum.find(plan.blocks, &(&1.id == block_id))

    new_blocks =
      Enum.map(plan.blocks, fn b ->
        if b.id == block_id, do: %{b | completed_task_ids: b.task_ids}, else: b
      end)

    new_plan = %{plan | blocks: new_blocks}
    new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}

    # Check if all blocks for each task are complete → mark task done
    new_state =
      if block do
        Enum.reduce(block.task_ids, new_state, fn task_id, acc ->
          if task_all_blocks_completed?(acc, task_id) do
            mark_task_done(acc, task_id)
          else
            acc
          end
        end)
      else
        new_state
      end

    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:add_task_to_block, date, block_id, task_id}, _from, %{state: state} = s) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))

    new_blocks =
      Enum.map(plan.blocks, fn block ->
        if block.id == block_id and task_id not in block.task_ids do
          %{block | task_ids: block.task_ids ++ [task_id]}
        else
          block
        end
      end)

    new_plan = %{plan | blocks: new_blocks}
    new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}
    new_state = mark_task_active(new_state, task_id)

    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call({:remove_task_from_block, date, block_id, task_id}, _from, %{state: state} = s) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))
    block = Enum.find(plan.blocks, &(&1.id == block_id))

    new_state =
      if block do
        new_task_ids = List.delete(block.task_ids, task_id)
        new_completed = List.delete(block.completed_task_ids, task_id)

        if new_task_ids == [] do
          # Last task removed — remove the entire block
          new_blocks = Enum.reject(plan.blocks, &(&1.id == block_id))
          new_plan = %{plan | blocks: new_blocks}
          new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}
          revert_task_if_unscheduled(new_state, task_id)
        else
          new_blocks =
            Enum.map(plan.blocks, fn b ->
              if b.id == block_id,
                do: %{b | task_ids: new_task_ids, completed_task_ids: new_completed},
                else: b
            end)

          new_plan = %{plan | blocks: new_blocks}
          new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}
          revert_task_if_unscheduled(new_state, task_id)
        end
      else
        state
      end

    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  def handle_call(
        {:complete_task_in_block, date, block_id, task_id},
        _from,
        %{state: state} = s
      ) do
    plan = Map.get(state.day_plans, date, DayPlan.new(date: date))

    new_blocks =
      Enum.map(plan.blocks, fn block ->
        if block.id == block_id and task_id not in block.completed_task_ids do
          %{block | completed_task_ids: block.completed_task_ids ++ [task_id]}
        else
          block
        end
      end)

    new_plan = %{plan | blocks: new_blocks}
    new_state = %{state | day_plans: Map.put(state.day_plans, date, new_plan)}

    # Check if all blocks for this task are now complete
    new_state =
      if task_all_blocks_completed?(new_state, task_id) do
        mark_task_done(new_state, task_id)
      else
        new_state
      end

    {:reply, :ok, schedule_save(%{s | state: new_state})}
  end

  @impl true
  def handle_info(:save, %{state: state} = s) do
    persist(state)
    broadcast(state)
    {:noreply, %{s | save_timer: nil}}
  end

  # Private

  defp schedule_save(%{save_timer: timer} = s) do
    if timer, do: Process.cancel_timer(timer)
    new_timer = Process.send_after(self(), :save, @debounce_ms)
    broadcast(s.state)
    %{s | save_timer: new_timer}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:state_updated, state})
  end

  defp load_state do
    File.mkdir_p!(data_dir())
    File.mkdir_p!(backup_dir())

    case File.read(state_file()) do
      {:ok, json} ->
        case State.from_json(json) do
          {:ok, state} -> state
          {:error, _} -> load_from_backup()
        end

      {:error, _} ->
        State.new()
    end
  end

  defp load_from_backup do
    case File.ls(backup_dir()) do
      {:ok, files} when files != [] ->
        latest =
          files
          |> Enum.sort(:desc)
          |> List.first()

        case File.read(Path.join(backup_dir(), latest)) do
          {:ok, json} ->
            case State.from_json(json) do
              {:ok, state} -> state
              {:error, _} -> State.new()
            end

          {:error, _} ->
            State.new()
        end

      _ ->
        State.new()
    end
  end

  defp persist(state) do
    File.mkdir_p!(data_dir())
    File.mkdir_p!(backup_dir())

    # Backup existing file
    if File.exists?(state_file()) do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:\.]/, "-")
      backup_path = Path.join(backup_dir(), "state-#{timestamp}.json")
      File.cp(state_file(), backup_path)
      cleanup_backups()
    end

    File.write!(state_file(), State.to_json(state))
  end

  defp cleanup_backups do
    case File.ls(backup_dir()) do
      {:ok, files} ->
        files
        |> Enum.sort(:desc)
        |> Enum.drop(20)
        |> Enum.each(fn f -> File.rm(Path.join(backup_dir(), f)) end)

      _ ->
        :ok
    end
  end

  defp mark_task_active(state, nil), do: state

  defp mark_task_active(state, task_id) do
    new_tasks =
      Enum.map(state.tasks, fn task ->
        if task.id == task_id and task.status == "ready" do
          %{task | status: "active"}
        else
          task
        end
      end)

    %{state | tasks: new_tasks}
  end

  defp mark_task_done(state, nil), do: state

  defp mark_task_done(state, task_id) do
    new_tasks =
      Enum.map(state.tasks, fn task ->
        if task.id == task_id, do: %{task | status: "done"}, else: task
      end)

    %{state | tasks: new_tasks}
  end

  defp revert_task_if_unscheduled(state, nil), do: state

  defp revert_task_if_unscheduled(state, task_id) do
    still_scheduled? =
      state.day_plans
      |> Map.values()
      |> Enum.any?(fn plan ->
        Enum.any?(plan.blocks, &(task_id in &1.task_ids))
      end)

    if still_scheduled? do
      state
    else
      new_tasks =
        Enum.map(state.tasks, fn task ->
          if task.id == task_id and task.status == "active" do
            %{task | status: "ready"}
          else
            task
          end
        end)

      %{state | tasks: new_tasks}
    end
  end

  defp task_all_blocks_completed?(state, task_id) do
    all_blocks =
      state.day_plans
      |> Map.values()
      |> Enum.flat_map(& &1.blocks)
      |> Enum.filter(&(task_id in &1.task_ids))

    all_blocks != [] and Enum.all?(all_blocks, &(task_id in &1.completed_task_ids))
  end

  defp validate_depends_on(%{project_id: nil} = task, _all_tasks) do
    %{task | depends_on: []}
  end

  defp validate_depends_on(task, all_tasks) do
    valid_ids =
      all_tasks
      |> Enum.filter(&(&1.id != task.id && &1.project_id == task.project_id))
      |> MapSet.new(& &1.id)

    %{task | depends_on: Enum.filter(task.depends_on, &(&1 in valid_ids))}
  end

  defp maybe_put(struct, _key, nil), do: struct
  defp maybe_put(struct, key, value), do: Map.put(struct, key, value)

  # Sets the key if it exists in the keyword list (even if nil — for clearing optional fields)
  defp maybe_put_if_key(struct, attrs, key) do
    if Keyword.has_key?(attrs, key),
      do: Map.put(struct, key, attrs[key]),
      else: struct
  end
end
