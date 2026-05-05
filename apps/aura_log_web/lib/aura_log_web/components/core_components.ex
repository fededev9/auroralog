defmodule AuraLogWeb.CoreComponents do
  @moduledoc """
  Core UI components shared across LiveViews.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr(:flash, :map, required: true)
  attr(:id, :string, default: "flash-group")

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  attr(:id, :string, default: nil)
  attr(:flash, :map, default: %{})
  attr(:title, :string, default: nil)
  attr(:kind, :atom, values: [:info, :error], default: :info)
  attr(:rest, :global)
  slot(:inner_block)

  def flash(assigns) do
    assigns =
      assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      class={[
        "al-flash",
        @kind == :info && "al-flash-info",
        @kind == :error && "al-flash-error"
      ]}
      role="alert"
      {@rest}
    >
      <div class="al-flash-content">
        <strong :if={@title}>{@title}</strong>
        <span>{msg}</span>
      </div>
      <button type="button" aria-label="close">
        <.icon name="hero-x-mark" class="al-flash-close" />
      </button>
    </div>
    """
  end

  attr(:name, :string, required: true)
  attr(:class, :string, default: "size-4")

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def show(js \\ %JS{}, selector), do: JS.show(js, to: selector, transition: "fade-in-scale")
  def hide(js \\ %JS{}, selector), do: JS.hide(js, to: selector, transition: "fade-out-scale")
end
