defmodule DayStruct.StoreTest do
  use ExUnit.Case

  alias DayStruct.Store

  setup do
    Store.reset!()
    :ok
  end

  describe "default state" do
    test "has 4 areas" do
      state = Store.get_state()
      assert length(state.areas) == 4
    end

    test "has empty tasks" do
      assert Store.get_tasks() == []
    end

    test "has empty inbox" do
      assert Store.get_inbox_items() == []
    end
  end

  describe "capture/1" do
    test "adds an item to inbox" do
      {:ok, item} = Store.capture("Buy milk")
      assert item.text == "Buy milk"

      items = Store.get_inbox_items()
      assert length(items) == 1
      assert hd(items).text == "Buy milk"
    end

    test "appends multiple items" do
      Store.capture("First")
      Store.capture("Second")
      items = Store.get_inbox_items()
      assert length(items) == 2
    end
  end

  describe "process_inbox_item/3" do
    test "converts inbox item to task and removes from inbox" do
      {:ok, item} = Store.capture("Build feature")
      [area | _] = Store.get_areas()

      {:ok, task} = Store.process_inbox_item(item.id, area.id, "Build feature X")
      assert task.title == "Build feature X"
      assert task.area_id == area.id
      assert task.status == "ready"

      assert Store.get_inbox_items() == []
      assert length(Store.get_tasks()) == 1
    end

    test "returns error for non-existent item" do
      assert {:error, :not_found} = Store.process_inbox_item("fake-id", "a", "title")
    end
  end

  describe "discard_inbox_item/1" do
    test "removes item from inbox" do
      {:ok, item} = Store.capture("Discard me")
      assert length(Store.get_inbox_items()) == 1

      :ok = Store.discard_inbox_item(item.id)
      assert Store.get_inbox_items() == []
    end
  end

  describe "create_task/1" do
    test "creates a task" do
      [area | _] = Store.get_areas()
      {:ok, task} = Store.create_task(title: "New task", area_id: area.id)

      assert task.title == "New task"
      assert length(Store.get_tasks()) == 1
    end
  end

  describe "update_task/2" do
    test "updates task fields" do
      [area | _] = Store.get_areas()
      {:ok, task} = Store.create_task(title: "Original", area_id: area.id)

      {:ok, updated} = Store.update_task(task.id, title: "Updated")
      assert updated.title == "Updated"
    end
  end

  describe "delete_task/1" do
    test "removes task" do
      [area | _] = Store.get_areas()
      {:ok, task} = Store.create_task(title: "Delete me", area_id: area.id)
      assert length(Store.get_tasks()) == 1

      :ok = Store.delete_task(task.id)
      assert Store.get_tasks() == []
    end
  end

  describe "time block CRUD" do
    setup do
      [area | _] = Store.get_areas()
      {:ok, task} = Store.create_task(title: "Schedulable", area_id: area.id, status: "ready")
      date = Date.utc_today() |> Date.to_iso8601()
      %{task: task, date: date}
    end

    test "add_time_block marks task as active", %{task: task, date: date} do
      {:ok, block} = Store.add_time_block(date, task_id: task.id, start_minute: 480, duration_minutes: 60)
      assert block.task_id == task.id

      updated_task = Store.get_task(task.id)
      assert updated_task.status == "active"
    end

    test "complete_time_block marks task as done when all blocks complete", %{task: task, date: date} do
      {:ok, block} = Store.add_time_block(date, task_id: task.id, start_minute: 480, duration_minutes: 60)

      Store.complete_time_block(date, block.id)
      updated_task = Store.get_task(task.id)
      assert updated_task.status == "done"
    end

    test "remove_time_block reverts task to ready", %{task: task, date: date} do
      {:ok, block} = Store.add_time_block(date, task_id: task.id, start_minute: 480, duration_minutes: 60)
      assert Store.get_task(task.id).status == "active"

      Store.remove_time_block(date, block.id)
      assert Store.get_task(task.id).status == "ready"
    end
  end

  describe "PubSub broadcasts" do
    test "mutations broadcast state_updated" do
      Store.subscribe()

      [area | _] = Store.get_areas()
      Store.create_task(title: "Test", area_id: area.id)

      assert_receive {:state_updated, state}
      assert length(state.tasks) == 1
    end
  end
end
