defmodule AuraLog.Parser.Service do
  @moduledoc """
  Parses normalized log envelopes by format, delegated to Rust NIFs.
  """

  alias AuraLog.Parser.NIF

  def parse_batch(events) when is_list(events) do
    lines = Enum.map(events, & &1.raw_line)

    case safe_parse_batch(lines) do
      {:ok, parsed_rows} ->
        merge_rows(events, parsed_rows)

      {:error, reason} ->
        # If the Rust parser fails/panics, gracefully degrade to per-line parsing.
        fallback_parse(events, reason)
    end
  end

  defp safe_parse_batch(lines) do
    task =
      Task.Supervisor.async_nolink(AuraLog.Parser.TaskSupervisor, fn ->
        NIF.parse_log_batch(lines)
      end)

    case Task.yield(task, 2_500) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, rows}} when is_list(rows) -> {:ok, rows}
      {:ok, rows} when is_list(rows) -> {:ok, rows}
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, other} -> {:error, {:unexpected_result, other}}
      nil -> {:error, :timeout}
    end
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp merge_rows(events, parsed_rows) do
    events
    |> Enum.zip(parsed_rows)
    |> Enum.reduce(%{rows: [], errors: []}, fn {event, row}, acc ->
      merged = Map.merge(base_fields(event), row || %{})

      if parse_success?(merged) do
        %{acc | rows: [merged | acc.rows]}
      else
        %{acc | errors: [error_from_event(event, merged["parse_error"]) | acc.errors]}
      end
    end)
    |> reverse_result()
  end

  defp fallback_parse(events, reason) do
    Enum.reduce(events, %{rows: [], errors: []}, fn event, acc ->
      case safe_parse_line(event.raw_line) do
        {:ok, row} ->
          merged = Map.merge(base_fields(event), row)

          if parse_success?(merged) do
            %{acc | rows: [merged | acc.rows]}
          else
            %{acc | errors: [error_from_event(event, merged["parse_error"]) | acc.errors]}
          end

        {:error, parse_reason} ->
          wrapped = {:batch_failed, reason, parse_reason}
          %{acc | errors: [error_from_event(event, wrapped) | acc.errors]}
      end
    end)
    |> reverse_result()
  end

  defp safe_parse_line(line) do
    case NIF.parse_log_line(line) do
      {:ok, row} when is_map(row) -> {:ok, row}
      row when is_map(row) -> {:ok, row}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_row, other}}
    end
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp error_from_event(event, reason) do
    %{
      tenant: event.tenant,
      source: event.source,
      timestamp: event.timestamp,
      raw_line: event.raw_line,
      reason: inspect(reason)
    }
  end

  defp reverse_result(result) do
    %{rows: Enum.reverse(result.rows), errors: Enum.reverse(result.errors)}
  end

  defp parse_success?(row) do
    parse_error = Map.get(row, "parse_error") || Map.get(row, :parse_error)
    parse_error in [nil, ""]
  end

  defp base_fields(event) do
    %{
      tenant: event.tenant,
      source: event.source,
      ts: event.timestamp,
      raw: event.raw_line,
      metadata: event.metadata
    }
  end
end
