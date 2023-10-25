defmodule StorageTest do
  use ExUnit.Case, async: true

  test "store values by key" do
    assert Storage.get("hello") == nil

    Storage.set("hello", "world")
    assert Storage.get("hello") == "world"
  end
end
