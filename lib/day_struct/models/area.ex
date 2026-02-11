defmodule DayStruct.Models.Area do
  @derive Jason.Encoder
  defstruct [:id, :name, :color, :position]

  def new(attrs) do
    %__MODULE__{
      id: attrs[:id] || UUID.uuid4(),
      name: attrs[:name],
      color: attrs[:color],
      position: attrs[:position] || 0
    }
  end

  def from_map(map) do
    %__MODULE__{
      id: map["id"],
      name: map["name"],
      color: map["color"],
      position: map["position"]
    }
  end

  def default_areas do
    [
      new(name: "Work", color: "blue", position: 0),
      new(name: "Physical movement", color: "green", position: 1),
      new(name: "Time with Trine", color: "rose", position: 2),
      new(name: "Misc private", color: "amber", position: 3)
    ]
  end
end
