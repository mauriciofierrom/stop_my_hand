import { onRoundStart, onRoundEnd, onReview, onNextRound } from './round_ui'
import { resetCountdown, hide } from '../util'
import { components } from './components'

export const createAndJoinMatchChannel = (socket, matchId, conferenceManager) => {
  const channel = socket.channel(`match:${matchId}`)
  let timeoutId
  let currentLetter
  let removeEvents

  channel.on("game_start", ({ countdown, letter }) => {
    currentLetter = letter
    timeoutId = resetCountdown(timeoutId, countdown,
      d => components.roundTimeout.textContent = d,
      () => {
        hide(components.roundTimeout);
        ({ removeEvents, timeoutId } = onRoundStart(letter, channel, timeoutId))
      }
    )
  })

  channel.on("round_start", ({ letter }) => {
    currentLetter = letter;
    ({ removeEvents, timeoutId } = onRoundStart(letter, channel, timeoutId))
  })

  channel.on("round_finished", () => {
    clearInterval(timeoutId)
    onRoundEnd(currentLetter, channel, removeEvents)
  })

  channel.on("in_review", ({ category }) => {
    timeoutId = onReview(category, timeoutId)
  })

  channel.on("next_round", ({ timeout }) => {
    timeoutId = onNextRound(timeout, timeoutId)
  })

  channel.on("show_scores", () => window.dispatchEvent(new CustomEvent("match:score")))
  channel.on("player_activity", (params) => window.dispatchEvent(new CustomEvent("match:onPlayerActivity", { detail: params })))
  channel.on("game_finished", () => window.location = "/")

  if(conferenceManager) {
    channel.on("peer_joined", ({ user_id }) => conferenceManager.handlePeerJoined(user_id))
    channel.on("peer_left", ({ user_id }) => conferenceManager.removePeer(user_id))
  }

  channel.join()
    .receive("ok", resp => console.log("Joined match channel", resp))
    .receive("error", resp => console.log("Unable to join match channel", resp))

  return channel
}
