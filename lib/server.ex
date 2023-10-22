defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Task.Supervisor, name: __MODULE__.TaskSupervisor},
        {Task, fn -> Server.listen() end}
      ],
      strategy: :one_for_one
    )
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} = :gen_tcp.listen(6379, [:binary, active: false, reuseaddr: true])

    loop_acceptor(socket)
  end

  @spec serve(:gen_tcp.socket()) :: any
  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(
        __MODULE__.TaskSupervisor,
        fn -> serve(client) end
      )

    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  @spec serve(:gen_tcp.socket()) :: any
  defp serve(socket) do
    with {:ok, _} <- do_recv(socket) do
      write(socket, "+PONG\r\n")
      serve(socket)
    end
  end

  defp do_recv(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write(socket, packet) do
    :gen_tcp.send(socket, packet)
  end
end
