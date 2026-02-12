defmodule DayStruct.Models.Project do
  @derive Jason.Encoder
  defstruct [:id, :name, :area_id, :status]

  def new(attrs) do
    %__MODULE__{
      id: attrs[:id] || UUID.uuid4(),
      name: attrs[:name],
      area_id: attrs[:area_id],
      status: attrs[:status] || "active"
    }
  end

  def from_map(map) do
    %__MODULE__{
      id: map["id"],
      name: map["name"],
      area_id: map["area_id"],
      status: map["status"]
    }
  end
end
