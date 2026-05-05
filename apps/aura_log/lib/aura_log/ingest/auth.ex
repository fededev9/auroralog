defmodule AuraLog.Ingest.Auth do
  @moduledoc """
  JWT authentication utilities for ingest endpoints.
  """

  @spec authorize(Plug.Conn.t()) ::
          {:ok, map(), String.t()} | {:error, :unauthorized | :forbidden}
  def authorize(conn) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, claims} <- verify_token(token),
         {:ok, tenant} <- tenant_from_claims(claims) do
      {:ok, claims, tenant}
    else
      {:error, :expired} -> {:error, :unauthorized}
      {:error, :missing_tenant} -> {:error, :forbidden}
      _ -> {:error, :unauthorized}
    end
  end

  def verify_token(token) do
    signer = Joken.Signer.create("HS256", jwt_secret())

    case Joken.verify(token, signer) do
      {:ok, claims} -> validate_claims(claims)
      {:error, _reason} -> {:error, :invalid_token}
    end
  end

  defp validate_claims(%{"sub" => _, "exp" => exp} = claims) do
    now = System.system_time(:second)

    cond do
      not is_integer(exp) -> {:error, :invalid_exp}
      exp < now -> {:error, :expired}
      true -> {:ok, claims}
    end
  end

  defp validate_claims(_), do: {:error, :missing_claims}

  defp tenant_from_claims(%{"tenant" => tenant}) when is_binary(tenant) and tenant != "",
    do: {:ok, tenant}

  defp tenant_from_claims(_), do: {:error, :missing_tenant}

  defp bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _ -> {:error, :missing_bearer}
    end
  end

  defp jwt_secret do
    Application.get_env(:aura_log, :ingest_jwt_secret, "dev-jwt-secret-change-me")
  end
end
