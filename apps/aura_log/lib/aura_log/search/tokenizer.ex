defmodule AuraLog.Search.Tokenizer do
  @moduledoc """
  Tokenizes log text for `log_terms` indexing (Rust NIF with Elixir fallback).
  """

  alias AuraLog.Parser.NIF

  @min_term_length 2

  @doc """
  Returns a deduplicated list of lowercase terms suitable for search indexing.
  """
  @spec terms_for(String.t()) :: [String.t()]
  def terms_for(text) when is_binary(text) do
    text
    |> safe_tokenize()
    |> Enum.filter(&(is_binary(&1) and String.length(&1) >= @min_term_length))
    |> Enum.uniq()
  end

  def terms_for(_), do: []

  @doc """
  Splits a user search query into terms (same rules as indexing).
  """
  @spec query_terms(String.t()) :: [String.t()]
  def query_terms(query) do
    query
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.filter(&(String.length(&1) >= @min_term_length))
    |> Enum.uniq()
  end

  defp safe_tokenize(message) do
    case NIF.tokenize_for_search(message) do
      {:ok, terms} when is_list(terms) -> normalize_nif_terms(terms, message)
      terms when is_list(terms) -> normalize_nif_terms(terms, message)
      _ -> fallback_tokenize(message)
    end
  rescue
    _ -> fallback_tokenize(message)
  end

  # NIF must return a proper list of UTF-8 binaries; charlists / nested lists break Enum.* in 1.19.
  defp normalize_nif_terms(terms, message) do
    if proper_binary_list?(terms) do
      Enum.map(terms, &String.downcase/1)
    else
      fallback_tokenize(message)
    end
  end

  defp proper_binary_list?(terms) do
    :erlang.is_list(terms) and not improper_list?(terms) and Enum.all?(terms, &is_binary/1)
  end

  defp improper_list?(list) do
    case list do
      [_ | tail] when is_list(tail) -> improper_list?(tail)
      [_ | _] -> true
      _ -> false
    end
  end

  defp fallback_tokenize(message) do
    message
    |> String.downcase()
    |> String.split(~r/[^a-z0-9_]+/, trim: true)
  end
end
