defmodule DayStruct.Models.TaskTest do
  use ExUnit.Case, async: true

  alias DayStruct.Models.Task

  describe "new/1" do
    test "creates a task with defaults" do
      task = Task.new(title: "Do something", area_id: "area-1")
      assert task.title == "Do something"
      assert task.area_id == "area-1"
      assert task.status == "ready"
      assert task.x == 0.5
      assert task.y == 0.85
      assert task.depends_on == []
      assert task.id != nil
      assert task.created_at != nil
      assert task.updated_at != nil
    end

    test "overrides defaults with provided values" do
      task = Task.new(title: "Custom", area_id: "a", status: "active", x: 0.1, y: 0.2)
      assert task.status == "active"
      assert task.x == 0.1
      assert task.y == 0.2
    end
  end

  describe "blocked?/2" do
    test "returns false when no dependencies" do
      task = Task.new(title: "T", area_id: "a", depends_on: [])
      refute Task.blocked?(task, [])
    end

    test "returns false when all dependencies are done" do
      dep = Task.new(title: "Dep", area_id: "a", status: "done")
      task = Task.new(title: "T", area_id: "a", depends_on: [dep.id])
      refute Task.blocked?(task, [dep, task])
    end

    test "returns true when a dependency is not done" do
      dep = Task.new(title: "Dep", area_id: "a", status: "ready")
      task = Task.new(title: "T", area_id: "a", depends_on: [dep.id])
      assert Task.blocked?(task, [dep, task])
    end

    test "returns false when dependency id is not found" do
      task = Task.new(title: "T", area_id: "a", depends_on: ["nonexistent"])
      refute Task.blocked?(task, [task])
    end
  end

  describe "schedulable?/2" do
    test "ready and unblocked task is schedulable" do
      task = Task.new(title: "T", area_id: "a", status: "ready", y: 0.2)
      assert Task.schedulable?(task, [task])
    end

    test "active and unblocked task is schedulable" do
      task = Task.new(title: "T", area_id: "a", status: "active", y: 0.2)
      assert Task.schedulable?(task, [task])
    end

    test "done task is not schedulable" do
      task = Task.new(title: "T", area_id: "a", status: "done")
      refute Task.schedulable?(task, [task])
    end

    test "dropped task is not schedulable" do
      task = Task.new(title: "T", area_id: "a", status: "dropped")
      refute Task.schedulable?(task, [task])
    end

    test "blocked task is not schedulable" do
      dep = Task.new(title: "Dep", area_id: "a", status: "ready")
      task = Task.new(title: "T", area_id: "a", status: "ready", y: 0.2, depends_on: [dep.id])
      refute Task.schedulable?(task, [dep, task])
    end

    test "task above today line is schedulable" do
      task = Task.new(title: "T", area_id: "a", status: "ready", y: 0.2)
      assert Task.schedulable?(task, [task])
    end

    test "task on today line is schedulable" do
      task = Task.new(title: "T", area_id: "a", status: "ready", y: 0.33)
      assert Task.schedulable?(task, [task])
    end

    test "task below today line is not schedulable" do
      task = Task.new(title: "T", area_id: "a", status: "ready", y: 0.5)
      refute Task.schedulable?(task, [task])
    end
  end
end
