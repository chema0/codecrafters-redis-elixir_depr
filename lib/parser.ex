defmodule Parser do
  defmodule ParseError do
    @moduledoc """
    Error in parsing data according to the
    [RESP](http://redis.io/topics/protocol) protocol.
    """

    defexception [:message]
  end

  @type redis_value :: binary | integer | nil | Redix.Error.t() | [redis_value]
  @type on_parse(value) :: {:ok, value, binary} | {:continuation, (binary -> on_parse(value))}

  @crlf "\r\n"

  @spec parse(binary()) :: on_parse(redis_value)
  def parse(data)

  def parse("*" <> rest), do: parse_array(rest)
  def parse(":" <> rest), do: parse_integer(rest)
  def parse("+" <> rest), do: parse_simple_string(rest)
  def parse("$" <> rest), do: parse_bulk_string(rest)
  def parse(""), do: {:continuation, &parse/1}

  def parse(<<byte>> <> _),
    do: raise(ParseError, message: "invalid type specifier (#{inspect(<<byte>>)})")

  defp parse_integer("-" <> rest), do: resolve_cont(parse_unsigned_integer(rest), &{:ok, -&1, &2})

  defp parse_integer(bin) do
    parse_unsigned_integer(bin)
  end

  defp parse_unsigned_integer(<<digit, _::binary>> = bin) when digit in ?0..?9 do
    resolve_cont(parse_integer_digits(bin, 0), fn i, rest ->
      resolve_cont(until_crlf(rest), fn
        "", rest ->
          {:ok, i, rest}

        <<char, _::binary>>, _rest ->
          raise ParseError, message: "expected CRLF, found #{inspect(<<char>>)}"
      end)
    end)
  end

  defp parse_unsigned_integer(<<non_digit, _::binary>>) do
    raise ParseError, message: "expected integer, found: #{inspect(<<non_digit>>)}"
  end

  defp parse_integer_digits(<<digit, rest::binary>>, acc) when digit in ?0..?9,
    do: parse_integer_digits(rest, acc * 10 + (digit - ?0))

  defp parse_integer_digits(<<_non_digit, _::binary>> = rest, acc), do: {:ok, acc, rest}

  defp parse_integer_digits(<<>>, acc), do: {:continuation, &parse_integer_digits(&1, acc)}

  defp parse_simple_string(bin) do
    case until_crlf(bin) do
      {:ok, str, rest} ->
        {:ok, String.downcase(str), rest}

      data ->
        data
    end
  end

  defp parse_bulk_string(rest) do
    resolve_cont(parse_integer(rest), fn
      -1, rest ->
        {:ok, nil, rest}

      size, rest ->
        parse_string_of_known_size(rest, size)
    end)
  end

  defp parse_string_of_known_size(data, size) do
    case data do
      <<str::bytes-size(size), @crlf, rest::binary>> ->
        {:ok, String.downcase(str), rest}

      _ ->
        {:continuation, &parse_string_of_known_size(data <> &1, size)}
    end
  end

  defp parse_array(rest) do
    resolve_cont(parse_integer(rest), fn
      -1, rest ->
        {:ok, nil, rest}

      size, rest ->
        take_elems(rest, size, [])
    end)
  end

  defp until_crlf(data, acc \\ "")

  defp until_crlf(<<@crlf, rest::binary>>, acc), do: {:ok, acc, rest}
  defp until_crlf(<<>>, acc), do: {:continuation, &until_crlf(&1, acc)}
  defp until_crlf(<<?\r>>, acc), do: {:continuation, &until_crlf(<<?\r, &1::binary>>, acc)}

  defp until_crlf(<<byte, rest::binary>>, acc),
    do: until_crlf(rest, <<acc::binary, byte>>)

  defp take_elems(data, 0, acc) do
    {:ok, Enum.reverse(acc), data}
  end

  defp take_elems(<<_, _::binary>> = data, n, acc) when n > 0 do
    resolve_cont(parse(data), fn elem, rest ->
      take_elems(rest, n - 1, [elem | acc])
    end)
  end

  defp take_elems(<<>>, n, acc) do
    {:continuation, &take_elems(&1, n, acc)}
  end

  defp resolve_cont({:ok, val, rest}, ok) when is_function(ok, 2), do: ok.(val, rest)

  defp resolve_cont({:continuation, cont}, ok),
    do: {:continuation, fn new_data -> resolve_cont(cont.(new_data), ok) end}
end
