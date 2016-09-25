defmodule ExRedisPool.HostUtil do
  @moduledoc """
  Helper utilities to parse the Redis host argument.
  """
  require Logger

  def resolve(host) do
    cond do
      is_ip_address?(host) == true ->
        Logger.debug("ip host: #{host}")
        host
      true ->
        host_ip = resolve_hostname(host)
        Logger.debug("host #{host} resolved to: #{host_ip}")
        host_ip
    end
  end

  def resolve_hostname(host) do
    case lookup(host) do
      {:ok, host_ip}   -> ip_to_string(host_ip)
      {:error, reason} -> raise(reason)
    end
  end

  def is_ip_address?(host) do
    case :inet.parse_address(to_char_list(host)) do
      {:ok, _}    -> true
      {:error, _} -> false
    end
  end

  def lookup(host) do
    case :inet.gethostbyname(to_char_list(host)) do
      {:ok, {:hostent, _, _, _, _, []}} ->
        {:error, :invalid_host}
      {:ok, {:hostent, _, _, _, _, results}} ->
        [host_ip] = Enum.take_random(results, 1)
        {:ok, host_ip}
      _ ->
        {:error, :invalid_host}
    end
  end

  def ip_to_string({octet_1, octet_2, octet_3, octet_4}) do
    {octet_1, octet_2, octet_3, octet_4}
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  def ip_to_string({hextet_1, hextet_2, hextet_3, hextet_4, hextet_5, hextet_6, hextet_7, hextet_8}) do
    {hextet_1, hextet_2, hextet_3, hextet_4, hextet_5, hextet_6, hextet_7, hextet_8}
    |> Tuple.to_list()
    |> Enum.join(":")
  end
end
