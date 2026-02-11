defmodule DayStruct.Models.InboxItem do
  @derive Jason.Encoder
  defstruct [:id, :text, :created_at]

  def new(attrs) do
    %__MODULE__{
      id: attrs[:id] || UUID.uuid4(),
      text: attrs[:text],
      created_at: attrs[:created_at] || DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  def from_map(map) do
    %__MODULE__{
      id: map["id"],
      text: map["text"],
      created_at: map["created_at"]
    }
  end
end
