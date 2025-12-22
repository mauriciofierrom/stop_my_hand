defmodule StopMyhand.ScoreTest do
  use StopMyHand.DataCase

  alias StopMyHand.Game.Score

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
  describe "round_scores/2" do
    test "when the answer is accepted it affords full points" do
      round_data = %{
        1 => %{
          handle: "P1",
          answers: %{
            name: %{
              value: "Link",
              reviews: %{
                2 => :accepted
              }
            }
          }
        },
        2 => %{
          handle: "P1",
          answers: %{
            name: %{
              value: "Lupin",
              reviews: %{
                1 => :accepted
              }
            }
          }
        }
      }

      assert Score.scores(round_data)[1].answers.name.result == %Score{points: 100, reason: :accepted}
      assert Score.scores(round_data)[2].answers.name.result == %Score{points: 100, reason: :accepted}
    end

    test "when the answer is accepted and duplicated it affords half points to the players that answered the same value" do
      round_data = %{
        1 => %{
          handle: "P1",
          answers: %{
            name: %{
              value: "Link",
              reviews: %{
                2 => :accepted
              }
            }
          }
        },
        2 => %{
          handle: "P1",
          answers: %{
            name: %{
              value: "Link",
              reviews: %{
                1 => :accepted
              }
            }
          }
        }
      }

      assert Score.scores(round_data)[1].answers.name.result == %Score{points: 50, reason: :accepted}
      assert Score.scores(round_data)[2].answers.name.result == %Score{points: 50, reason: :accepted}
    end

    test "when the answer is rejected it affords zero points" do
      round_data = %{
        1 => %{
          handle: "P1",
          answers: %{
            thing: %{
              value: "exs",
              reviews: %{
                2 => :rejected
              }
            }
          }
        },
      }

      assert Score.scores(round_data)[1].answers.thing.result == %Score{points: 0, reason: :rejected}
    end

    test "when the answer is empty it affords zero points" do
      round_data = %{
        1 => %{
          handle: "P1",
          answers: %{
            thing: %{
              value: "",
              reviews: %{
                2 => :none
              }
            }
          }
        },
      }

      assert Score.scores(round_data)[1].answers.thing.result == %Score{points: 0, reason: :empty}
    end
  end
end
