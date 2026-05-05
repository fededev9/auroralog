defmodule AuraLog.Parser.Contracts do
  @moduledoc """
  Shared types and contracts for Elixir <-> Rust NIF payloads.
  """

  @typedoc "Raw normalized input event"
  @type ingest_event :: %{
          required(:tenant) => String.t(),
          required(:source) => String.t(),
          required(:timestamp) => String.t(),
          required(:raw_line) => String.t(),
          optional(:metadata) => map()
        }

  @typedoc "NIF parser output row"
  @type parsed_row :: %{
          optional(String.t()) => String.t(),
          optional(atom()) => String.t() | number() | boolean()
        }

  @typedoc "NIF parsing result"
  @type parse_result :: %{rows: [parsed_row()], errors: [map()]}
end
