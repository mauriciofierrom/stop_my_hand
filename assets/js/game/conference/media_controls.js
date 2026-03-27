import { components } from "../components"

/**
 * Initializes local media stream and sets up camera/mic toggle controls.
 * @param {Object} conferenceManager - ConferenceManager instance
 */
export const setupMediaControls = async (conferenceManager) => {
  const localStream = await conferenceManager.initialize()
  components.localVideo.muted = true
  components.localVideo.srcObject = localStream

  components.localCamera.addEventListener('click', () => {
    const enabled = conferenceManager.toggleCamera()
    const icon = components.localCamera.firstElementChild
    if (enabled) {
      icon.classList.remove('hero-video-camera-slash')
      icon.classList.add('hero-video-camera')
    } else {
      icon.classList.remove('hero-video-camera')
      icon.classList.add('hero-video-camera-slash')
    }
  })

  components.localMic.addEventListener('click', () => {
    const enabled = conferenceManager.toggleMicrophone()
    const icon = components.localMic.firstElementChild
    if (enabled) {
      icon.classList.remove('opacity-50', 'text-red-500')
    } else {
      icon.classList.add('opacity-50', 'text-red-500')
    }
  })
}

/**
 * Handles an incoming remote track by attaching it to the peer's video element.
 * @param {string} peerId
 * @param {MediaStreamTrack} track
 * @param {MediaStream} stream
 */
export const onRemoteTrack = (peerId, track, stream) => {
  const videoElement = components.peerVideo(peerId)
  if (videoElement && !videoElement.srcObject) {
    videoElement.srcObject = stream
  }
}
