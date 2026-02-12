defmodule DayStruct.Store.State do
  alias DayStruct.Models.{Area, Task, InboxItem, DayPlan, Project}

  @derive Jason.Encoder
  defstruct areas: [], tasks: [], inbox_items: [], day_plans: %{}, projects: []

  def new do
    %__MODULE__{
      areas: Area.default_areas(),
      tasks: [],
      inbox_items: [],
      day_plans: %{},
      projects: []
    }
  end

  def from_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, map} -> {:ok, from_map(map)}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_json(%__MODULE__{} = state) do
    Jason.encode!(state, pretty: true)
  end

  defp from_map(map) do
    %__MODULE__{
      areas: (map["areas"] || []) |> Enum.map(&Area.from_map/1),
      tasks: (map["tasks"] || []) |> Enum.map(&Task.from_map/1),
      inbox_items: (map["inbox_items"] || []) |> Enum.map(&InboxItem.from_map/1),
      day_plans:
        (map["day_plans"] || %{})
        |> Enum.into(%{}, fn {date, plan} -> {date, DayPlan.from_map(plan)} end),
      projects: (map["projects"] || []) |> Enum.map(&Project.from_map/1)
    }
  end
end
