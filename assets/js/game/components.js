export const components = (() => {
  let roundTimeout, gameElement, letterElement, localCamera, localMic, localVideo, gameFields

  return {
    get roundTimeout() { return roundTimeout ??= document.querySelector('#counter') },
    get gameElement() { return gameElement ??= document.querySelector('#game') },
    get letterElement() { return letterElement ??= document.querySelector('#letter') },
    get localCamera() { return localCamera ??= document.querySelector('#local-camera') },
    get localMic() { return localMic ??= document.querySelector('#local-mic') },
    get localVideo() { return localVideo ??= document.querySelector('#local-video') },
    get gameFields() { return gameFields ??= document.querySelectorAll('#round input[type="text"]') },
    peerVideo: (peerId) => document.querySelector(`#peer-video-${peerId}`)
  }
})()
