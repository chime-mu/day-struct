defmodule DayStruct.Models.AreaTest do
  use ExUnit.Case, async: true

  alias DayStruct.Models.Area

  describe "new/1" do
    test "creates an area with provided values" do
      area = Area.new(name: "Work", color: "blue", position: 0)
      assert area.name == "Work"
      assert area.color == "blue"
      assert area.position == 0
      assert area.id != nil
    end

    test "defaults position to 0" do
      area = Area.new(name: "Test", color: "green")
      assert area.position == 0
    end
  end

  describe "default_areas/0" do
    test "returns 4 areas" do
      areas = Area.default_areas()
      assert length(areas) == 4
    end

    test "areas have expected names" do
      names = Area.default_areas() |> Enum.map(& &1.name)
      assert "Work" in names
      assert "Physical movement" in names
      assert "Time with Trine" in names
      assert "Misc private" in names
    end

    test "areas have sequential positions" do
      positions = Area.default_areas() |> Enum.map(& &1.position)
      assert positions == [0, 1, 2, 3]
    end

    test "each area has a unique id" do
      ids = Area.default_areas() |> Enum.map(& &1.id)
      assert length(Enum.uniq(ids)) == 4
    end
  end
end
