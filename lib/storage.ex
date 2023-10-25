defmodule Storage do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  def set(key, value, opts \\ []) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))

    with {:ok, ttl} <- Keyword.fetch(opts, :ttl) do
      :timer.apply_after(ttl, __MODULE__, :delete, [key])
    end
  end

  def delete(key) do
    Agent.update(__MODULE__, &Map.delete(&1, key))
  end
end
