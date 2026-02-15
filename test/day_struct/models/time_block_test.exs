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
    test "creates a time block with snapped values using task_id" do
      block = TimeBlock.new(task_id: "task-1", start_minute: 482, duration_minutes: 37)
      assert block.task_ids == ["task-1"]
      assert block.start_minute == 480
      assert block.duration_minutes == 30
      assert block.completed_task_ids == []
      assert block.id != nil
    end

    test "creates a time block with task_ids list" do
      block = TimeBlock.new(task_ids: ["t1", "t2"], start_minute: 480, duration_minutes: 60)
      assert block.task_ids == ["t1", "t2"]
      assert block.completed_task_ids == []
    end

    test "uses defaults when values not provided" do
      block = TimeBlock.new(task_id: "t")
      assert block.start_minute == 480
      assert block.duration_minutes == 30
    end
  end

  describe "from_map/1 migration" do
    test "migrates old task_id format to task_ids" do
      block =
        TimeBlock.from_map(%{
          "id" => "b1",
          "task_id" => "t1",
          "start_minute" => 480,
          "duration_minutes" => 60
        })

      assert block.task_ids == ["t1"]
      assert block.completed_task_ids == []
    end

    test "migrates old completed: true to completed_task_ids" do
      block =
        TimeBlock.from_map(%{
          "id" => "b1",
          "task_id" => "t1",
          "start_minute" => 480,
          "duration_minutes" => 60,
          "completed" => true
        })

      assert block.task_ids == ["t1"]
      assert block.completed_task_ids == ["t1"]
    end

    test "reads new task_ids format" do
      block =
        TimeBlock.from_map(%{
          "id" => "b1",
          "task_ids" => ["t1", "t2"],
          "start_minute" => 480,
          "duration_minutes" => 60,
          "completed_task_ids" => ["t1"]
        })

      assert block.task_ids == ["t1", "t2"]
      assert block.completed_task_ids == ["t1"]
    end
  end

  describe "completed?/1" do
    test "returns true when all tasks are completed" do
      block = %TimeBlock{
        id: "b1",
        task_ids: ["t1", "t2"],
        completed_task_ids: ["t1", "t2"],
        start_minute: 480,
        duration_minutes: 60
      }

      assert TimeBlock.completed?(block)
    end

    test "returns false when not all tasks are completed" do
      block = %TimeBlock{
        id: "b1",
        task_ids: ["t1", "t2"],
        completed_task_ids: ["t1"],
        start_minute: 480,
        duration_minutes: 60
      }

      refute TimeBlock.completed?(block)
    end

    test "returns false when no tasks are completed" do
      block = %TimeBlock{
        id: "b1",
        task_ids: ["t1"],
        completed_task_ids: [],
        start_minute: 480,
        duration_minutes: 60
      }

      refute TimeBlock.completed?(block)
    end

    test "returns false when task_ids is empty" do
      block = %TimeBlock{
        id: "b1",
        task_ids: [],
        completed_task_ids: [],
        start_minute: 480,
        duration_minutes: 60
      }

      refute TimeBlock.completed?(block)
    end
  end
end
