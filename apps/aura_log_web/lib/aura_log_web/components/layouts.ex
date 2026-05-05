defmodule AuraLogWeb.Layouts do
  @moduledoc """
  Application layouts and shared wrappers.
  """
  use AuraLogWeb, :html

  embed_templates("layouts/*")

  attr(:flash, :map, required: true)
  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <header class="al-shell-header">
      <a href="/dashboard" class="al-brand">
        <span class="al-dot"></span>
        <span>AuraLog</span>
      </a>
    </header>
    <main class="al-shell-main">
      <%= render_slot(@inner_block) %>
    </main>
    <.flash_group flash={@flash} />
    """
  end
end
