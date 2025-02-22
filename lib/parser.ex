defmodule JsonPathAccess.Parser do
  import NimbleParsec

  space = string(" ")
  root = string("$")

  number =
    optional(string("-"))
    |> integer(min: 1)
    |> reduce({Enum, :join, []})
    |> map({String, :to_integer, []})

  name_first = ascii_string([?A..?Z, ?a..?z, ?_], min: 1)
  name_char = ascii_string([?A..?Z, ?a..?z, ?0..?9], min: 1)

  dot_member_name =
    name_first
    |> optional(name_char)
    |> reduce({Enum, :join, []})

  dot_selector =
    ignore(string("."))
    |> concat(dot_member_name)

  dot_wildcard_selector =
    ignore(string(".*"))
    |> post_traverse({:all, []})

  wildcard_index_selector =
    ignore(string("[*]"))
    |> post_traverse({:all, []})

  wildcard_selector = choice([wildcard_index_selector, dot_wildcard_selector])

  double_quoted_name_selector =
    ignore(string("[\""))
    |> utf8_string([?A..?Z, ?a..?z, ?_, ?\s, ?.], min: 1)
    |> ignore(string("\"]"))

  single_quoted_name_selector =
    ignore(string("['"))
    |> utf8_string([?A..?Z, ?a..?z, ?_, ?\s, ?.], min: 1)
    |> ignore(string("']"))

  quoted_selector = choice([single_quoted_name_selector, double_quoted_name_selector])

  element_index_selector =
    ignore(string("["))
    |> concat(number)
    |> ignore(string("]"))
    |> map({Access, :at, []})

  index_selector = choice([quoted_selector, element_index_selector])

  start_index = number
  end_index = number
  step = number

  slice_index =
    optional(start_index |> ignore(optional(space)))
    |> ignore(string(":"))
    |> ignore(optional(space))
    |> optional(end_index |> ignore(optional(space)))
    |> optional(ignore(string(":")) |> optional(ignore(optional(space)) |> concat(step)))

  array_slice_selector =
    ignore(string("["))
    |> ignore(optional(space))
    |> concat(slice_index)
    |> ignore(string("]"))
    |> post_traverse({:slice, []})

  json_path =
    ignore(root)
    |> concat(
      repeat(choice([dot_selector, wildcard_selector, index_selector, array_slice_selector]))
    )

  defparsec(:parse, json_path, debug: true)

  defp all(_rest, _args = [], context, _line, _offset) do
    {[Access.all()], context}
  end

  defp slice(rest, args = [_end_index, _start_index], context, line, offset) do
    slice(rest, [1 | args], context, line, offset)
  end

  defp slice(_rest, [step, end_index, start_index], context, _line, _offset) do
    {[Access.slice(start_index..(end_index - 1)//step)], context}
  end
end
