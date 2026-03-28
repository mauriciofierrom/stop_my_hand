// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix matchChannels client library:
import { Socket } from "phoenix"
import { ConferenceManager } from "./conference/conference_manager"
import { createUserChannel, joinUserChannel } from "./conference/user_channel"
import { createAndJoinMatchChannel } from "./match_channel"
import { setupMediaControls, onRemoteTrack } from "./conference/media_controls"

// And connect to the path in "lib/stop_my_hand_web/endpoint.ex". We pass the
// token for authentication. Read below how it should be used.
let socket = new Socket("/game", { params: { token: window.userToken } })

export async function createMatch({ matchId, currentUserId, videoEnabled }) {
  if (!socket.isConnected()) {
    socket.connect()
  }

  let conferenceManager
  let userChannel

  console.log(videoEnabled);

  if (videoEnabled) {
    userChannel = createUserChannel(socket, currentUserId)

    conferenceManager = new ConferenceManager(
      userChannel,
      currentUserId,
      onRemoteTrack,
      (peerId, state) => {
        console.log(`Peer ${peerId} connection state: ${state}`)
      },
    )

    await setupMediaControls(conferenceManager)
  }

  const matchChannel = createAndJoinMatchChannel(
    socket,
    matchId,
    conferenceManager,
  )

  if (videoEnabled) {
    joinUserChannel(userChannel, conferenceManager)
  }
}

export default socket
