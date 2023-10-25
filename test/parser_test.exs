defmodule ParserTest do
  use ExUnit.Case, async: true

  import Parser

  test "parse_integer/1" do
    assert parse_integer(":10\r\n") == 10
  end

  test "parse_bulk_string/1" do
    assert parse_bulk_string("5\r\nhello\r\n") == "hello"
  end
end
