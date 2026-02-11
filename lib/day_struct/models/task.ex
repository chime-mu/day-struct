defmodule DayStruct.Models.Task do
  @derive Jason.Encoder
  defstruct [
    :id,
    :title,
    :description,
    :area_id,
    :status,
    :x,
    :y,
    :depends_on,
    :created_at,
    :updated_at
  ]

  def new(attrs) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    %__MODULE__{
      id: attrs[:id] || UUID.uuid4(),
      title: attrs[:title] || "",
      description: attrs[:description] || "",
      area_id: attrs[:area_id],
      status: attrs[:status] || "ready",
      x: attrs[:x] || 0.5,
      y: attrs[:y] || 0.85,
      depends_on: attrs[:depends_on] || [],
      created_at: attrs[:created_at] || now,
      updated_at: attrs[:updated_at] || now
    }
  end

  def from_map(map) do
    %__MODULE__{
      id: map["id"],
      title: map["title"],
      description: map["description"] || "",
      area_id: map["area_id"],
      status: map["status"],
      x: map["x"],
      y: map["y"],
      depends_on: map["depends_on"] || [],
      created_at: map["created_at"],
      updated_at: map["updated_at"]
    }
  end

  def blocked?(%__MODULE__{depends_on: deps}, all_tasks) when is_list(deps) do
    Enum.any?(deps, fn dep_id ->
      case Enum.find(all_tasks, &(&1.id == dep_id)) do
        nil -> false
        task -> task.status != "done"
      end
    end)
  end

  def blocked?(_task, _all_tasks), do: false

  def schedulable?(%__MODULE__{status: status} = task, all_tasks) do
    status in ["ready", "active"] and not blocked?(task, all_tasks)
  end
end
