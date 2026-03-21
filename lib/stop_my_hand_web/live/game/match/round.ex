defmodule StopMyHandWeb.Game.Match.Round do
  @moduledoc """
  This module provides a functional component for the active round's information
  """
  use Phoenix.Component
  use StopMyHandWeb, :html

  @doc """
  This view shows the information related to the current _Round_ of the match:

  - The **round number**
  - The active player's **current score**
  - The current **letter** at play
  """

  attr :round_number, :integer, required: true
  attr :score, :integer, required: true
  attr :current_letter, :string, default: ""

  def round_info(assigns) do
    ~H"""
      <h1 class="text-8xl">{gettext("ROUND")} {@round_number} - {@score}</h1>
      <div id="counter" class="shadow-md text-6xl" phx-update="ignore"></div>
      <div id="letter" class="text-8xl text-accent" phx-update="ignore">{@current_letter}</div>
    """
  end
end
