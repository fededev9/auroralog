defmodule AuraLogWeb.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest

      @endpoint AuraLogWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, _} = Application.ensure_all_started(:aura_log)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
