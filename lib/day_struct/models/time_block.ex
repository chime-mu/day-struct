defmodule DayStruct.Models.TimeBlock do
  @derive Jason.Encoder
  defstruct [:id, :task_id, :start_minute, :duration_minutes, :completed]

  def new(attrs) do
    %__MODULE__{
      id: attrs[:id] || UUID.uuid4(),
      task_id: attrs[:task_id],
      start_minute: snap_to_grid(attrs[:start_minute] || 480),
      duration_minutes: snap_to_grid(attrs[:duration_minutes] || 30),
      completed: attrs[:completed] || false
    }
  end

  def from_map(map) do
    %__MODULE__{
      id: map["id"],
      task_id: map["task_id"],
      start_minute: map["start_minute"],
      duration_minutes: map["duration_minutes"],
      completed: map["completed"] || false
    }
  end

  def snap_to_grid(minutes), do: round(minutes / 15) * 15

  def end_minute(%__MODULE__{start_minute: s, duration_minutes: d}), do: s + d

  def format_time(minutes) do
    h = div(minutes, 60)
    m = rem(minutes, 60)
    String.pad_leading("#{h}", 2, "0") <> ":" <> String.pad_leading("#{m}", 2, "0")
  end
end
