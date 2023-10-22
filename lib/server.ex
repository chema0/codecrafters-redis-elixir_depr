defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} = :gen_tcp.listen(6379, [:binary, active: false, reuseaddr: true])
    {:ok, client} = :gen_tcp.accept(socket)

    loop_acceptor(client)
  end

  @spec serve(:gen_tcp.socket()) :: any
  defp loop_acceptor(socket) do
    serve(socket)
    loop_acceptor(socket)
  end

  @spec serve(:gen_tcp.socket()) :: any
  defp serve(socket) do
    socket
    |> read()
    |> write("+PONG\r\n")
  end

  defp read(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, _} -> socket
      _ -> socket
    end
  end

  defp write(socket, packet) do
    :gen_tcp.send(socket, packet)
  end
end
