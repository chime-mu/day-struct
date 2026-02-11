defmodule DayStruct.Models.DayPlan do
  alias DayStruct.Models.TimeBlock

  @derive Jason.Encoder
  defstruct [:date, :blocks]

  def new(attrs) do
    %__MODULE__{
      date: attrs[:date] || Date.utc_today() |> Date.to_iso8601(),
      blocks: attrs[:blocks] || []
    }
  end

  def from_map(map) do
    %__MODULE__{
      date: map["date"],
      blocks: (map["blocks"] || []) |> Enum.map(&TimeBlock.from_map/1)
    }
  end
end
