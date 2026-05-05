defmodule AuraLogWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.
  """
  use AuraLogWeb, :html

  embed_templates("error_html/*")
end
