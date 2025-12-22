defmodule StopMyHand.Game.Score do
  defstruct [:points, :reason]

  @zero_points 0
  @full_points 100
  @half_points @full_points / 2
  @categories [:name, :last_name, :city, :color, :animal, :thing]

  def scores(round_data) do
    add_scores(round_data)
  end

  # 1 => %{
  #   answers: %{
  #     name: %{
  #       value: "Link",
  #       reviews: %{
  #         2 => :rejected
  #       }
  #     }
  #   }
  # }
  def default_player_data(player_ids) do
    for player_id <- player_ids, into: %{} do
      {
        player_id, %{
          answers: (for cat <- @categories, into: %{}, do: {
                      cat,
                      %{value: "", reviews: default_answer_reviews(player_ids)}})
       }
      }
    end
  end

  defp default_answer_reviews(all_player_ids) do
    for player_id <- all_player_ids, into: %{} do
      {player_id, :none}
    end
  end

  defp repeated_answers(round_data) do
    for category <- @categories, into: %{} do
      accepted_answers =
        for {_, data} <- round_data, {^category, %{reviews: reviews, value: answer}} <- data.answers, final_result(reviews) == :accepted, do: String.upcase(answer)

      repeated =
        accepted_answers
        |> Enum.frequencies()
        |> Enum.filter(fn {_answer, count} -> count > 1 end)
        |> Enum.map(fn {answer, _count} -> answer end)

      {category, repeated}
    end
  end

  defp add_scores(round_data) do
    repeated = repeated_answers(round_data)

    for {player_id, data} <- round_data, {category, answer} <- data.answers, reduce: round_data do
      acc ->
        result = final_result(answer.reviews)
        final_score = score(result, String.upcase(answer.value) in repeated[category])

        acc
        |> put_in([player_id, :answers, category, :result], %StopMyHand.Game.Score{points: final_score, reason: result})
    end
  end


  defp score(:empty, _repeated), do: @zero_points
  defp score(:rejected, _repeated), do: @zero_points
  defp score(:accepted, true),  do: @half_points
  defp score(:accepted, false) , do: @full_points

  defp final_result(reviews) do
    result_freq = Enum.frequencies(Map.values(reviews))
    cond do
      Map.keys(result_freq) == [:none] -> :empty
      Map.get(result_freq, :accepted, 0) >= Map.get(result_freq, :rejected, 0) -> :accepted
      true -> :rejected
    end
  end
end
