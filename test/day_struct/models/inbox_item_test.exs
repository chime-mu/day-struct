defmodule DayStruct.Models.InboxItemTest do
  use ExUnit.Case, async: true

  alias DayStruct.Models.InboxItem

  describe "new/1" do
    test "creates an inbox item" do
      item = InboxItem.new(text: "Buy groceries")
      assert item.text == "Buy groceries"
      assert item.id != nil
      assert item.created_at != nil
    end

    test "generates unique ids" do
      a = InboxItem.new(text: "A")
      b = InboxItem.new(text: "B")
      assert a.id != b.id
    end
  end
end
