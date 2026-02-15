defmodule DayStruct.Models.TimeBlock do
  @derive Jason.Encoder
  defstruct [:id, :task_ids, :start_minute, :duration_minutes, :completed_task_ids]

  def new(attrs) do
    task_ids =
      cond do
        attrs[:task_ids] -> attrs[:task_ids]
        attrs[:task_id] -> [attrs[:task_id]]
        true -> []
      end

    %__MODULE__{
      id: attrs[:id] || UUID.uuid4(),
      task_ids: task_ids,
      start_minute: snap_to_grid(attrs[:start_minute] || 480),
      duration_minutes: snap_to_grid(attrs[:duration_minutes] || 30),
      completed_task_ids: attrs[:completed_task_ids] || []
    }
  end

  def from_map(map) do
    # Migration: old format has "task_id" (string), new has "task_ids" (list)
    task_ids =
      cond do
        map["task_ids"] -> map["task_ids"]
        map["task_id"] -> [map["task_id"]]
        true -> []
      end

    # Migration: old format has "completed" (boolean), new has "completed_task_ids" (list)
    completed_task_ids =
      cond do
        map["completed_task_ids"] -> map["completed_task_ids"]
        map["completed"] == true -> task_ids
        true -> []
      end

    %__MODULE__{
      id: map["id"],
      task_ids: task_ids,
      start_minute: map["start_minute"],
      duration_minutes: map["duration_minutes"],
      completed_task_ids: completed_task_ids
    }
  end

  def completed?(%__MODULE__{task_ids: task_ids, completed_task_ids: completed_task_ids}) do
    task_ids != [] and MapSet.subset?(MapSet.new(task_ids), MapSet.new(completed_task_ids))
  end

  def snap_to_grid(minutes), do: round(minutes / 15) * 15

  def end_minute(%__MODULE__{start_minute: s, duration_minutes: d}), do: s + d

  def format_time(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    String.pad_leading("#{h}", 2, "0") <> ":" <> String.pad_leading("#{m}", 2, "0")
  end
end
