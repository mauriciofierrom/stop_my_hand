defmodule StopMyHandWeb.Dropdown do
  use StopMyHandWeb, :live_component
  alias Phoenix.LiveView.JS

  slot :button, required: true
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div class="relative inline-block text-left">
      <div>
        <a class="cursor-pointer" phx-click={drop_it("#dropdown_#{assigns.id}")} phx-target={@myself}>
          <%= render_slot(@button) %>
        </a>
      </div>

      <div
        id={"dropdown_#{assigns.id}"}
        class={[
          "absolute right-0 z-10 mt-2 w-56 origin-top-right rounded-md bg-white shadow-lg ring-1 ring-black/5 focus:outline-none hidden",
          "flex flex-column"
        ]}
        role="menu"
        tabindex="-1"
        phx-blur={drop_blur("#dropdown_#{assigns.id}")}>
          <div class="py-1" role="none">
            <%= render_slot(@inner_block) %>
          </div>
      </div>
    </div>
    """
  end

  def drop_it(js \\ %JS{}, id) do
    js
    |> JS.show(
      to: id,
      transition:
        {
          "transition ease-out duration-100",
          "transform opacity-0 scale-95",
          "transform opacity-100 scale-100"
        }
    ) |> JS.focus(to: id)
  end

  def drop_blur(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: id,
      transition:
        {
          "transition ease-in duration-75",
          "transform opacity-100 scale-100",
          "transform opacity-0 scale-95"
        }
    )
  end
end
