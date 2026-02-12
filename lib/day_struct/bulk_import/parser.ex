defmodule DayStruct.BulkImport.Parser do
  @moduledoc """
  Parses Logseq journal text into individual inbox items.

  Parsing rules:
  - `###` headers become context labels, not items
  - Each top-level line (first indent level) becomes its own inbox item
  - Sub-items (deeper indentation) bundle into their parent item
  - Items get prefixed with their header context: `[Early morning] Ring til Norwegian...`
  - Logseq markup stripped: `[[links]]` -> `links`, checkboxes, properties, etc.
  """

  @type parsed_item :: %{text: String.t(), context: String.t() | nil, selected: boolean()}

  @spec parse(String.t()) :: [parsed_item()]
  def parse(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> classify_lines()
    |> group_items()
    |> Enum.map(fn {context, main_line, sub_lines} ->
      formatted = format_item(context, main_line, sub_lines)
      %{text: formatted, context: context, selected: true}
    end)
    |> Enum.reject(fn item -> item.text == "" end)
  end

  def parse(_), do: []

  @doc """
  Strips Logseq markup from text.
  """
  @spec strip_markup(String.t()) :: String.t()
  def strip_markup(text) do
    text
    |> strip_page_links()
    |> strip_todo_keywords()
    |> strip_checkboxes()
    |> strip_properties()
    |> strip_queries()
    |> strip_bold_italic()
    |> strip_bullet_prefix()
    |> collapse_whitespace()
    |> String.trim()
  end

  # Line classification

  defp classify_lines(lines) do
    Enum.map(lines, fn line ->
      cond do
        header?(line) -> {:header, extract_header(line)}
        blank?(line) -> :blank
        true -> {:content, indent_level(line), strip_markup(line)}
      end
    end)
  end

  defp header?(line), do: String.match?(line, ~r/^\#{2,}\s+/)
  defp blank?(line), do: String.trim(line) == ""

  defp extract_header(line) do
    line
    |> String.replace(~r/^\#+\s+/, "")
    |> strip_markup()
    |> String.trim()
  end

  defp indent_level(line) do
    case Regex.run(~r/^(\s*)/, line) do
      [_, spaces] -> String.length(spaces)
      _ -> 0
    end
  end

  # Grouping lines into items

  defp group_items(classified) do
    {items, _current_context, current_item} =
      Enum.reduce(classified, {[], nil, nil}, fn
        {:header, text}, {items, _ctx, current} ->
          items = flush_item(items, current)
          {items, text, nil}

        :blank, {items, ctx, current} ->
          items = flush_item(items, current)
          {items, ctx, nil}

        {:content, _indent, ""}, acc ->
          acc

        {:content, indent, text}, {items, ctx, nil} ->
          {items, ctx, {ctx, indent, text, []}}

        {:content, indent, text}, {items, ctx, {item_ctx, base_indent, main, subs}} ->
          if indent > base_indent do
            {items, ctx, {item_ctx, base_indent, main, subs ++ [text]}}
          else
            items = flush_item(items, {item_ctx, base_indent, main, subs})
            {items, ctx, {ctx, indent, text, []}}
          end
      end)

    flush_item(items, current_item)
    |> Enum.map(fn {ctx, _indent, main, subs} -> {ctx, main, subs} end)
  end

  defp flush_item(items, nil), do: items
  defp flush_item(items, item), do: items ++ [item]

  # Formatting

  defp format_item(nil, main_line, []), do: main_line
  defp format_item(nil, main_line, sub_lines) do
    ([main_line] ++ Enum.map(sub_lines, &("  " <> &1)))
    |> Enum.join("\n")
  end
  defp format_item(context, main_line, []) do
    "[#{context}] #{main_line}"
  end
  defp format_item(context, main_line, sub_lines) do
    (["[#{context}] #{main_line}"] ++ Enum.map(sub_lines, &("  " <> &1)))
    |> Enum.join("\n")
  end

  # Markup stripping

  defp strip_page_links(text) do
    # [[page links]] -> page links
    String.replace(text, ~r/\[\[([^\]]+)\]\]/, "\\1")
  end

  defp strip_todo_keywords(text) do
    # Remove TODO/DONE/NOW/LATER at start of line content
    String.replace(text, ~r/\b(TODO|DONE|NOW|LATER)\s+/, "")
  end

  defp strip_checkboxes(text) do
    text
    |> String.replace(~r/\[[ xX]\]\s*/, "")
  end

  defp strip_properties(text) do
    # key:: value properties - remove entire match
    if String.match?(text, ~r/^[a-zA-Z_-]+::\s/) do
      ""
    else
      # Inline properties
      String.replace(text, ~r/[a-zA-Z_-]+::\s\S+/, "")
    end
  end

  defp strip_queries(text) do
    String.replace(text, ~r/\{\{[^}]*\}\}/, "")
  end

  defp strip_bold_italic(text) do
    text
    |> String.replace(~r/\*\*([^*]+)\*\*/, "\\1")
    |> String.replace(~r/_([^_]+)_/, "\\1")
  end

  defp strip_bullet_prefix(text) do
    # Remove leading - or * bullet markers
    String.replace(text, ~r/^\s*[-*]\s+/, fn match ->
      # Preserve the indentation but remove the bullet
      spaces = String.replace(match, ~r/[-*]\s+$/, "")
      spaces
    end)
  end

  defp collapse_whitespace(text) do
    text
    |> String.replace(~r/\s{2,}/, " ")
    |> String.trim()
  end
end
