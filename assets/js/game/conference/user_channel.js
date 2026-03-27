export const createUserChannel = (socket, userId) =>
  socket.channel(`user:${userId}`)

export const joinUserChannel = (channel, conferenceManager) => {
  channel.on("webrtc_offer", ({ sender_id, offer }) => conferenceManager.handleOffer(sender_id, offer))
  channel.on("webrtc_answer", ({ sender_id, answer }) => conferenceManager.handleAnswer(sender_id, answer))
  channel.on("webrtc_ice_candidate", ({ sender_id, candidate }) => conferenceManager.handleIceCandidate(sender_id, candidate))

  channel.join()
    .receive("ok", resp => console.log("Joined signal channel", resp))
    .receive("error", resp => console.log("Unable to join signal channel", resp))
}
