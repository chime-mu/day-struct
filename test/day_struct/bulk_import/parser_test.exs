defmodule DayStruct.BulkImport.ParserTest do
  use ExUnit.Case

  alias DayStruct.BulkImport.Parser

  describe "parse/1" do
    test "returns empty list for empty input" do
      assert Parser.parse("") == []
      assert Parser.parse("   ") == []
      assert Parser.parse("\n\n\n") == []
    end

    test "returns empty list for non-string input" do
      assert Parser.parse(nil) == []
      assert Parser.parse(42) == []
    end

    test "parses simple lines as individual items" do
      input = """
      Buy milk
      Call dentist
      Fix bug
      """

      items = Parser.parse(input)
      assert length(items) == 3
      assert Enum.at(items, 0).text == "Buy milk"
      assert Enum.at(items, 1).text == "Call dentist"
      assert Enum.at(items, 2).text == "Fix bug"
    end

    test "all items are selected by default" do
      items = Parser.parse("Item one\nItem two")
      assert Enum.all?(items, & &1.selected)
    end

    test "headers become context labels" do
      input = """
      ### Morning
      Exercise
      Meditate
      """

      items = Parser.parse(input)
      assert length(items) == 2
      assert Enum.at(items, 0).text == "[Morning] Exercise"
      assert Enum.at(items, 0).context == "Morning"
      assert Enum.at(items, 1).text == "[Morning] Meditate"
    end

    test "multiple headers create different contexts" do
      input = """
      ### Morning
      Exercise
      ### Evening
      Read book
      """

      items = Parser.parse(input)
      assert length(items) == 2
      assert Enum.at(items, 0).text == "[Morning] Exercise"
      assert Enum.at(items, 1).text == "[Evening] Read book"
    end

    test "sub-items bundle into parent" do
      input = """
      Main task
        Sub-task A
        Sub-task B
      """

      items = Parser.parse(input)
      assert length(items) == 1
      assert items |> hd() |> Map.get(:text) == "Main task\n  Sub-task A\n  Sub-task B"
    end

    test "sub-items with header context" do
      input = """
      ### Work
      Deploy app
        Run tests first
        Update changelog
      """

      items = Parser.parse(input)
      assert length(items) == 1
      assert hd(items).text == "[Work] Deploy app\n  Run tests first\n  Update changelog"
    end

    test "new top-level line starts new item after sub-items" do
      input = """
      First task
        Sub of first
      Second task
      """

      items = Parser.parse(input)
      assert length(items) == 2
      assert Enum.at(items, 0).text == "First task\n  Sub of first"
      assert Enum.at(items, 1).text == "Second task"
    end

    test "blank lines separate items" do
      input = """
      Task one

      Task two
      """

      items = Parser.parse(input)
      assert length(items) == 2
    end

    test "items without headers have nil context" do
      items = Parser.parse("No header item")
      assert hd(items).context == nil
    end
  end

  describe "strip_markup/1" do
    test "strips page links" do
      assert Parser.strip_markup("Check [[project]]") == "Check project"
      assert Parser.strip_markup("[[page one]] and [[page two]]") == "page one and page two"
    end

    test "strips TODO keywords" do
      assert Parser.strip_markup("TODO Buy groceries") == "Buy groceries"
      assert Parser.strip_markup("DONE Finish report") == "Finish report"
      assert Parser.strip_markup("NOW Working on this") == "Working on this"
      assert Parser.strip_markup("LATER Schedule meeting") == "Schedule meeting"
    end

    test "strips checkboxes" do
      assert Parser.strip_markup("[ ] Unchecked item") == "Unchecked item"
      assert Parser.strip_markup("[x] Checked item") == "Checked item"
      assert Parser.strip_markup("[X] Also checked") == "Also checked"
    end

    test "strips properties (full line)" do
      assert Parser.strip_markup("priority:: high") == ""
      assert Parser.strip_markup("due:: 2024-01-15") == ""
    end

    test "strips queries" do
      assert Parser.strip_markup("{{query stuff}}") == ""
      assert Parser.strip_markup("Before {{embed something}} after") == "Before after"
    end

    test "strips bold and italic" do
      assert Parser.strip_markup("This is **bold** text") == "This is bold text"
      assert Parser.strip_markup("This is _italic_ text") == "This is italic text"
    end

    test "strips bullet prefixes" do
      assert Parser.strip_markup("- Bullet item") == "Bullet item"
      assert Parser.strip_markup("* Star item") == "Star item"
    end

    test "handles combined markup" do
      assert Parser.strip_markup("- TODO [[project]] task **important**") == "project task important"
    end
  end

  describe "parse/1 with Logseq journal content" do
    test "parses realistic Logseq journal entry" do
      input = """
      ### Early morning
      - Ring til [[Norwegian embassy]]
        - Ask about passport renewal
        - Bring documents
      - TODO Check [[flight prices]]
      ### Work
      - DONE Deploy staging
      - Review PR from [[John]]
        - Focus on auth changes
      """

      items = Parser.parse(input)
      assert length(items) == 4

      assert Enum.at(items, 0).text == "[Early morning] Ring til Norwegian embassy\n  Ask about passport renewal\n  Bring documents"
      assert Enum.at(items, 0).context == "Early morning"

      assert Enum.at(items, 1).text == "[Early morning] Check flight prices"
      assert Enum.at(items, 1).context == "Early morning"

      assert Enum.at(items, 2).text == "[Work] Deploy staging"
      assert Enum.at(items, 2).context == "Work"

      assert Enum.at(items, 3).text == "[Work] Review PR from John\n  Focus on auth changes"
      assert Enum.at(items, 3).context == "Work"
    end

    test "skips property-only lines" do
      input = """
      ### Notes
      priority:: high
      Actual content here
      """

      items = Parser.parse(input)
      assert length(items) == 1
      assert hd(items).text == "[Notes] Actual content here"
    end
  end
end
