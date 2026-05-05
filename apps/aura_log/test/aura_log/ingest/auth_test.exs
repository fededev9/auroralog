defmodule AuraLog.Ingest.AuthTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias AuraLog.Ingest.Auth

  describe "verify_token/1" do
    test "accepts valid HS256 claims" do
      token = mint(%{"sub" => "u1", "tenant" => "t1"})
      assert {:ok, claims} = Auth.verify_token(token)
      assert claims["sub"] == "u1"
      assert claims["tenant"] == "t1"
    end

    test "rejects expired token" do
      token =
        mint_direct(%{
          "sub" => "u1",
          "tenant" => "t1",
          "exp" => System.system_time(:second) - 60
        })

      assert {:error, :expired} = Auth.verify_token(token)
    end
  end

  describe "authorize/1" do
    test "rejects missing bearer" do
      conn = conn(:post, "/ingest", "{}")
      assert {:error, :unauthorized} == Auth.authorize(conn)
    end

    test "rejects when tenant claim is missing" do
      token =
        mint_direct(%{
          "sub" => "only-sub",
          "exp" => System.system_time(:second) + 600
        })

      conn =
        conn(:post, "/ingest", "{}")
        |> put_req_header("authorization", "Bearer #{token}")

      assert {:error, :forbidden} == Auth.authorize(conn)
    end
  end

  defp mint(extra) when is_map(extra) do
    base = %{
      "sub" => "default-sub",
      "tenant" => "default-tenant",
      "exp" => System.system_time(:second) + 600
    }

    mint_direct(Map.merge(base, extra))
  end

  defp mint_direct(claims) when is_map(claims) do
    secret = Application.fetch_env!(:aura_log, :ingest_jwt_secret)
    signer = Joken.Signer.create("HS256", secret)
    {:ok, token, _} = Joken.encode_and_sign(claims, signer)
    token
  end
end
