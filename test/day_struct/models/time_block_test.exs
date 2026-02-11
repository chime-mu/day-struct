defmodule DayStruct.Models.TimeBlockTest do
  use ExUnit.Case, async: true

  alias DayStruct.Models.TimeBlock

  describe "snap_to_grid/1" do
    test "rounds to nearest 15 minutes" do
      assert TimeBlock.snap_to_grid(0) == 0
      assert TimeBlock.snap_to_grid(7) == 0
      assert TimeBlock.snap_to_grid(8) == 15
      assert TimeBlock.snap_to_grid(15) == 15
      assert TimeBlock.snap_to_grid(22) == 15
      assert TimeBlock.snap_to_grid(23) == 30
      assert TimeBlock.snap_to_grid(480) == 480
    end
  end

  describe "end_minute/1" do
    test "returns start + duration" do
      block = TimeBlock.new(task_id: "t", start_minute: 480, duration_minutes: 60)
      assert TimeBlock.end_minute(block) == 540
    end
  end

  describe "format_time/1" do
    test "formats minutes as HH:MM" do
      assert TimeBlock.format_time(0) == "00:00"
      assert TimeBlock.format_time(60) == "01:00"
      assert TimeBlock.format_time(480) == "08:00"
      assert TimeBlock.format_time(510) == "08:30"
      assert TimeBlock.format_time(1320) == "22:00"
    end
  end

  describe "new/1" do
    test "creates a time block with snapped values" do
      block = TimeBlock.new(task_id: "task-1", start_minute: 482, duration_minutes: 37)
      assert block.task_id == "task-1"
      assert block.start_minute == 480
      assert block.duration_minutes == 30
      assert block.completed == false
      assert block.id != nil
    end

    test "uses defaults when values not provided" do
      block = TimeBlock.new(task_id: "t")
      assert block.start_minute == 480
      assert block.duration_minutes == 30
    end
  end
end
