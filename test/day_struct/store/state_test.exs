defmodule DayStruct.Store.StateTest do
  use ExUnit.Case, async: true

  alias DayStruct.Store.State
  alias DayStruct.Models.{Area, Task, InboxItem, DayPlan, TimeBlock}

  describe "new/0" do
    test "creates state with default areas" do
      state = State.new()
      assert length(state.areas) == 4
      assert state.tasks == []
      assert state.inbox_items == []
      assert state.day_plans == %{}
    end
  end

  describe "JSON round-trip" do
    test "empty state survives round-trip" do
      state = State.new()
      json = State.to_json(state)
      assert {:ok, restored} = State.from_json(json)

      assert length(restored.areas) == length(state.areas)
      assert restored.tasks == []
      assert restored.inbox_items == []
      assert restored.day_plans == %{}
    end

    test "state with tasks survives round-trip" do
      state = %State{
        areas: [Area.new(name: "Work", color: "blue", position: 0)],
        tasks: [Task.new(title: "Do thing", area_id: "a1")],
        inbox_items: [InboxItem.new(text: "Quick thought")],
        day_plans: %{
          "2026-02-11" => %DayPlan{
            date: "2026-02-11",
            blocks: [TimeBlock.new(task_id: "t1", start_minute: 480, duration_minutes: 60)]
          }
        }
      }

      json = State.to_json(state)
      assert {:ok, restored} = State.from_json(json)

      assert length(restored.areas) == 1
      assert hd(restored.areas).name == "Work"
      assert length(restored.tasks) == 1
      assert hd(restored.tasks).title == "Do thing"
      assert length(restored.inbox_items) == 1
      assert hd(restored.inbox_items).text == "Quick thought"
      assert map_size(restored.day_plans) == 1
      plan = restored.day_plans["2026-02-11"]
      assert length(plan.blocks) == 1
      assert hd(plan.blocks).start_minute == 480
    end

    test "from_json returns error for invalid JSON" do
      assert {:error, _} = State.from_json("not json")
    end
  end
end
