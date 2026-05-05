defmodule AuraLog.Parser.NIF do
  @moduledoc """
  Rust NIF bindings for compute-heavy parsing and tokenization.
  """
  use Rustler,
    otp_app: :aura_log,
    crate: "auralog_core",
    path: "../../native/auralog_core"

  def parse_log_line(_line), do: :erlang.nif_error(:nif_not_loaded)
  def parse_log_batch(_lines), do: :erlang.nif_error(:nif_not_loaded)
  def flush_batch_to_duckdb(_duckdb_path, _rows), do: :erlang.nif_error(:nif_not_loaded)
  def detect_format(_line), do: :erlang.nif_error(:nif_not_loaded)
  def tokenize_for_search(_line), do: :erlang.nif_error(:nif_not_loaded)
end
