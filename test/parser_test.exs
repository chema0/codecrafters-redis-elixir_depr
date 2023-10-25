defmodule ParserTest do
  use ExUnit.Case, async: true

  import Parser

  test "parse_integer/1" do
    assert proxy(":10\r\n") == 10
  end

  test "parse_bulk_string/1" do
    # assert parse_bulk_string("5\r\nhello\r\n") == "hello"
  end

  defp proxy(data) do
    case parse(data) do
      {:ok, value, _} -> value
    end
  end
end
