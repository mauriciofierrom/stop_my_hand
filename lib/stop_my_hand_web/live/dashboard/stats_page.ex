defmodule StopMyHandWeb.Dashboard.StatsPage do
  use Phoenix.LiveDashboard.PageBuilder

  import StopMyHand.Accounts, only: [get_active_users_count: 0]
  import StopMyHand.Game, only: [get_created_match_count: 0]

  @impl true
  def menu_link(_, _) do
    {:ok, "Stats"}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.card_title title="Aggregates"/>
    <.row>
      <:col>
        <.card inner_title="# Users" hint="Number of active users">
          {get_active_users_count()}
        </.card>
      </:col>
      <:col>
        <.card inner_title="# Games" hint="Number of games created">
          {get_created_match_count()}
        </.card>
      </:col>
    </.row>
    """
  end
end
