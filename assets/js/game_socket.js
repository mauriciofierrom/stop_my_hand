// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix matchChannels client library:
import {Socket} from "phoenix"
import {ConferenceManager} from "./conference_manager"

// And connect to the path in "lib/stop_my_hand_web/endpoint.ex". We pass the
// token for authentication. Read below how it should be used.
let socket = new Socket("/game", {params: {token: window.userToken}})

let intervalId = null

export async function createMatch({matchId, currentUserId}) {
  console.log(`The current user id: ${currentUserId}`)
  if(!socket.isConnected()) {
    socket.connect()
  }

  let matchChannel = socket.channel(`match:${matchId}`)
  let userChannel = socket.channel(`user:${currentUserId}`)
  let currentLetter = null

  const cameraToggleBtn = document.querySelector('#local-camera')

  cameraToggleBtn.addEventListener('click', () => {
    console.log("Camera click")
    const enabled = conferenceManager.toggleCamera()
    const icon = cameraToggleBtn.firstElementChild

    if (enabled) {
      icon.classList.remove('hero-video-camera-slash')
      icon.classList.add('hero-video-camera')
    } else {
      icon.classList.remove('hero-video-camera')
      icon.classList.add('hero-video-camera-slash')
    }
  })

  const micToggleBtn = document.querySelector('#local-mic')

  micToggleBtn.addEventListener('click', (e) => {
    console.log("Microphone click")
    const enabled = conferenceManager.toggleMicrophone()
    const icon = micToggleBtn.firstElementChild

    if (enabled) {
      icon.classList.remove('opacity-50', 'text-red-500')
    } else {
      icon.classList.add('opacity-50', 'text-red-500')
    }
  })

  const counterElement = document.querySelector("#counter")
  const gameFields = document.querySelectorAll('#round input[type="text"]')
  const conferenceManager = new ConferenceManager(
    userChannel,
    currentUserId,
    (peerId, track, stream) => {
      console.log("On remote track!")
      // Find or create v"local-video"ideo element for this peer
      let videoElement = document.querySelector(`#peer-video-${peerId}`)

      // Set the stream as source
      videoElement.srcObject = stream
    },
    (peerId, state) => {
      console.log(`Peer ${peerId} connection state: ${state}`)
    }
  );

  matchChannel.join()
    .receive("ok", resp => {
      console.log("Joined match channel successfully", resp);

      userChannel.join()
        .receive("ok", resp => {
          console.log("Joined signal channel successfully", resp);

          conferenceManager.initialize().then(localStream => {
            let ownVideoElement = document.querySelector('#local-video');
            ownVideoElement.srcObject = localStream;
            ownVideoElement.muted = true;
          });
        })
        .receive("error", resp => { console.log("Unable to join signal channel", resp) });
    })
    .receive("error", resp => { console.log("Unable to join match channel", resp) });

  // matchChannel.join()
  //   .receive("ok", async resp => {
  //     console.log("Joined match channel successfully", resp)
  //   })
  //   .receive("error", resp => { console.log("Unable to join match channel", resp) })


  // userChannel.join()
  //   .receive("ok", async resp => {
  //     console.log("Joined signal channel successfully", resp)
  //   })
  //   .receive("error", resp => { console.log("Unable to join signal channel", resp) })

  // let ownVideoElement = document.querySelector('#local-video')
  // let localStream = await conferenceManager.initialize()
  // ownVideoElement.srcObject = localStream
  // ownVideoElement.muted = true

  matchChannel.on("game_start", ({ countdown, letter, round }) => {
    console.log(`GAME START - Countdown: ${countdown}. First letter: ${letter}`)
    let counter = countdown
    currentLetter = letter
    intervalId = setInterval(() => {
      counter--
      if(counter > 0) {
        counterElement.innerHTML = counter
      } else {
        clearInterval(intervalId)

        // Hide counter
        counterElement.classList.add("hidden")

        // Show game element
        const gameElement = document.querySelector("#game")
        gameElement.classList.remove("hidden")

        // Pick new game letter
        const letterElement = document.querySelector("#letter")

        // Set the letter element
        letterElement.innerHTML = `${letter}`
        addEvents(letter, gameFields, matchChannel)

        // Focus on the first elmeent to make it easier to start playing
        gameFields[0].focus()

        // Actions to perform when round starts
        onRoundStart(letter, matchChannel)
      }
    }, 1000)
  })

  matchChannel.on("round_finished", () => {
    console.log(`round finished!: ${currentLetter}`)
    clearInterval(intervalId)

    onRoundEnd(currentLetter, gameFields, matchChannel)
  })

  matchChannel.on("round_start", ({letter}) => {
    addEvents(letter, gameFields, matchChannel)
    console.log(`round starting ${letter}`)
    clearInterval(intervalId)
    currentLetter = letter
    gameFields.forEach(i => {
      i.classList.remove("disabled")
      i.disabled = false
    })
    onRoundStart(letter, matchChannel)
  })

  matchChannel.on("show_scores", () => {
    console.log("Show scores")
    window.dispatchEvent(new CustomEvent("match:score"))
  })

  matchChannel.on("next_round", ({timeout}) => {
    console.log("on next round")
    // Tell LV to reset the thingies
    window.dispatchEvent(new CustomEvent("match:reset"))

    console.log(`The countdown ${timeout}`)

    let countdown = timeout

    const roundTimeout = document.querySelector('#counter')
    const gameElement = document.querySelector("#game")

    gameElement.classList.add("hidden")

    clearInterval(intervalId)

    intervalId = setInterval(() => {
      countdown -= 1
      roundTimeout.innerHTML = formatTime(countdown)

      if(countdown === 0) {
        clearInterval(intervalId)
      }
    }, 1000)
  })

  matchChannel.on("in_review", ({category}) => {
    console.log(`matchChannel in_review category: ${category}`)
    onReview(category, matchChannel)
  })

  matchChannel.on("player_activity", (params) => {
    window.dispatchEvent(new CustomEvent("match:onPlayerActivity", {detail: params}))
  })

  matchChannel.on("game_finished", () => {
    console.log("GAME OVER!")
    window.location = "/"
  })

  matchChannel.on("peer_joined", ({ user_id }) => {
    conferenceManager.handlePeerJoined(user_id);
  });

  matchChannel.on("peer_left", ({ user_id }) => {
    conferenceManager.removePeer(user_id);
  });

  userChannel.on("webrtc_offer", ({ sender_id, offer }) => {
    conferenceManager.handleOffer(sender_id, offer);
  });

  userChannel.on("webrtc_answer", ({ sender_id, answer }) => {
    conferenceManager.handleAnswer(sender_id, answer);
  });

  userChannel.on("webrtc_ice_candidate", ({ sender_id, candidate }) => {
    conferenceManager.handleIceCandidate(sender_id, candidate);
  });

  return matchChannel
}

const handleEnterEvent = (matchChannel, letter, inputs) => {
  return (event => {
    if(event.key === "Enter" && validateFields(letter, inputs)) {
      matchChannel.push("player_finished", {letter})
    }
  })
}

const handleBlurEvent = (matchChannel, letter) => {
  return (event => {
    matchChannel.push("player_activity", {
      category: event.target.dataset.category,
      letter: letter,
      size: event.target.value.length
    })
  })
}

const isValid = (letter, input) =>
      input.value && input.value[0].toUpperCase() === letter.toUpperCase()

const validateFields = (letter, inputs) =>
  Array.from(inputs).every(i => isValid(letter, i))

const addEvents = (letter, inputs, matchChannel) => {
  inputs.forEach(input => {
    input.addEventListener("keypress", handleEnterEvent(matchChannel, letter, inputs))
    input.addEventListener("blur", handleBlurEvent(matchChannel, letter))
  })
}

const removeEvents = (letter, inputs, matchChannel) => {
  inputs.forEach(input => {
    removeEventListener("keypress", handleEnterEvent(matchChannel, letter, inputs))
    removeEventListener("blur", handleBlurEvent(matchChannel, letter))
  })
}

const calculateScore = (letter, inputs) =>
  Array.from(inputs).reduce((acc, i) => acc + (isValid(letter, i) ? 100 : 0), 0)

const onRoundStart = (letter, matchChannel) => {
  const roundTimeout = document.querySelector('#counter')
  const firstGameField = document.querySelector('#round input[type="text"]')
  let duration = 180

  roundTimeout.innerHTML = formatTime(duration)
  roundTimeout.classList.remove("hidden")

  // Show game element
  const gameElement = document.querySelector("#game")
  gameElement.classList.remove("hidden")

  // Focus on first input
  firstGameField.focus()

  // Pick new game letter
  const letterElement = document.querySelector("#letter")

  // Set the letter element
  letterElement.innerHTML = `${letter}`


  intervalId = setInterval(() => {
    duration -= 1
    roundTimeout.innerHTML = formatTime(duration)

    if(duration === 0) {
      clearInterval(intervalId)
      matchChannel.push("round_finished", {letter})
    }
  }, 1000)
}

const onRoundEnd = (letter, inputs, matchChannel) => {
  console.log("onRoundEnd")

  const roundTimeout = document.querySelector('#counter')
  // roundTimeout.classList.add("hidden")
  const letterElement = document.querySelector("#letter")

  letterElement.innerHTML = `Reviewing - ${letter}`

  console.log(inputs)

  inputs.forEach(i => {
    i.classList.add("disabled")
    i.disabled = true
  })

  removeEvents(letter, inputs, matchChannel)

  const answers = Object.fromEntries(Array.from(inputs).map(i => [i.dataset.category, i.value]))

  console.log(answers)
  matchChannel.push("report_answers", answers)
}

const onReview = (category, matchChannel) => {
  const counterElement = document.querySelector('#counter')
  const reviewTimeout = 10
  console.log(`The onReview category ${category}`)
  const event = new CustomEvent("match:review", { detail: {category: category} })
  let countdown = reviewTimeout

  counterElement.innerHTML = formatTime(countdown)
  counterElement.classList.remove("hidden")

  window.dispatchEvent(event)

  clearInterval(intervalId)

  intervalId = setInterval(() => {
    countdown -= 1
    counterElement.innerHTML = formatTime(countdown)

    if(countdown === 0) {
      clearInterval(intervalId)
      // Disable controls
      console.log("answer review timed out!")
    }
  }, 1000)
}

const formatTime = (seconds) => {
  const toMinute = (seconds) => Math.floor(seconds / 60)
  const toSecondsLeft = (seconds) => seconds % 60
  return `${toMinute(seconds).toString().padStart(2, '0')}:${toSecondsLeft(seconds).toString().padStart(2, '0')}`
}

export default socket
