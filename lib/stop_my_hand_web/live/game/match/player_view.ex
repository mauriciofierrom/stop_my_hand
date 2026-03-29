defmodule StopMyHandWeb.Game.Match.PlayerView do
  @moduledoc """
  This is the graphic view of the player.

  The view can be the video feed or the profile picture.
  """

  use StopMyHandWeb, :html

  @doc """
  The player view is the _graphical indicator_ for the player. It can be local
  (the current player) or remote (the other players). In case the match has
  videocalling enabled, the profile picture is replaced by the video feed, unless
  the player decides to stop the camera.

  Buttons to _mute the mic_ and _shut the camera off_ are also present in case the match
  has videocalling enabled.
  """

  attr :video_enabled, :boolean, doc: "Whether this view should contain video conferencing controls"
  attr :source, :atom, values: [:local, :remote], doc: "where does the view come from", required: true
  attr :peer_id, :integer, required: true

  def player_view(assigns) do
    ~H"""
    <div id={"player-view-#{@peer_id}"} phx-update="ignore" class="relative w-24 h-24 bg-gray-200 flex items-center justify-center text-gray-600 text-sm font-medium rounded-lg">
      <video :if={@video_enabled} autoplay class="w-24 h-24 object-cover" id={video_id(@source, @peer_id)} />
      <button :if={@source == :local} id="local-mic" class="absolute bottom-2 left-2 p-1.5 bg-black bg-opacity-50 rounded-full hover:bg-opacity-70">
          <i class="hero-microphone w-4 h-4 text-green-500"></i>
      </button>
      <button :if={@source == :local && @video_enabled} id="local-camera" class="absolute bottom-2 right-2 p-1.5 bg-black bg-opacity-50 rounded-full hover:bg-opacity-70">
          <i class="hero-video-camera-slash w-4 h-4 text-white"></i>
      </button>
    </div>
    """
  end

  @doc """
  The player activity view shows the values that the other players are doing
  by showing an obfuscated equivalent to what they've entered in a **Category**
  field.

  Obfuscation is done by replacing all the letters from the second letter on with
  the first letter. Thus _Waluigi_ becomes _WWWWWWW_. It's supposed to give a similar
  sense as when playing on a table and taking a glance at the answers of the other
  players. You probably can't quite make what they got, but you see that they have a
  value and roughly the size of it.
  """

  attr :player_activity, :map, required: true
  attr :player_id, :integer, required: true

  def player_activity(assigns) do
    ~H"""
      <div class="flex gap-2">
        <div :for={{category, activity} <- @player_activity[@player_id]} class="flex gap-2 items-center justify-center">
          <span class="font-bold text-xl">{translate_category(category)}:</span>
          <div class="flex flex-col items-center justify-center" data-testid={"#{category}-activity-#{@player_id}"}>
            {activity}
          </div>
        </div>
      </div>
    """
  end

  @doc """
  Player review shows the controls for players to perform review on the other players'
  answers.

  Players can either _reject_ the answer or _accept_ it. If they reject it and the majority
  does, the answer is annulled and gets a _zero_ score. If it's accepted it can pass to the
  next round of score calculation.
  """

  attr :player_id, :integer, required: true
  attr :player_data, :map, required: true
  attr :categories, :list, required: true
  attr :current_category, :atom, required: true
  attr :current_user_id, :integer, required: true

  def player_review(assigns) do
    ~H"""
    <div class="flex gap-2">
      <div :for={category <- @categories} class="flex gap-2 items-center justify-center">
        <span class="font-bold text-xl">{translate_category(category)}:</span>
        <div class="flex flex-col items-center justify-center">
          <.score :if={get_in(@player_data, [:answers, category, :result])} result={get_in(@player_data, [:answers, category, :result])} />
          <%= if @player_data.answers[category].value == "" do %>
            <span>--</span>
          <% else %>
            <div class={answer_class(get_in(@player_data.answers, [category, :reviews, @current_user_id]))}>
              {@player_data.answers[category].value}
            </div>
          <% end %>
        </div>
        <.button
          :if={category_submitted?(@current_category, category, @player_data.answers[category].value)}
          class={review_button_class(@player_data.answers[category].reviews[@current_user_id], :accepted)}
          phx-click="review_answer" phx-value-playerid={@player_id} phx-value-result="accepted">
          <.icon name="hero-check" />
        </.button>
        <.button
          :if={category_submitted?(@current_category, category, @player_data.answers[category].value)}
          class={review_button_class(@player_data.answers[category].reviews[@current_user_id], :rejected)}
          phx-click="review_answer" phx-value-playerid={@player_id} phx-value-result="rejected">
          <.icon name="hero-x-mark" />
        </.button>
      </div>
    </div>
    """
  end

  attr :result, :map, required: true

  def score(assigns) do
    ~H"""
      <div class={[points_class(@result.reason), "font-bold"]}>
        {@result.points}
      </div>
    """
  end

  defp answer_class(review) do
    case review do
      :accepted -> "text-green-600"
      :rejected -> "text-red-600"
      :none -> ""
    end
  end

  defp points_class(result) do
    case result do
      :accepted -> "text-green-600"
      :rejected -> "text-orange-600"
      :empty -> "text-red-600"
    end
  end

  defp video_id(:local, _peer_id), do: "local-video"
  defp video_id(:remote, peer_id), do: "peer-video-#{peer_id}"

  defp category_submitted?(current_category, category, value) do
    current_category == category && value != ""
  end

  defp review_button_class(value, expected) when value == expected, do: "bg-accent"
  defp review_button_class(_value, _expected), do: "bg-secondary"
end
