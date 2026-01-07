// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

// And connect to the path in "lib/stop_my_hand_web/endpoint.ex". We pass the
// token for authentication. Read below how it should be used.
let socket = new Socket("/game", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/stop_my_hand_web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/stop_my_hand_web/templates/layout/app.html.heex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/3" function
// in "lib/stop_my_hand_web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket, _connect_info) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1_209_600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, connect to the socket:
// socket.connect()

// Now that you are connected, you can join channels with a topic.
// Let's assume you have a channel with a topic named `room` and the
// subtopic is its id - in this case 42:

let intervalId = null

export function createMatch({matchId, timestamp}) {
  if(!socket.isConnected()) {
    socket.connect()
  }
  const offset = Math.abs(Date.now() - timestamp)
  let channel = socket.channel(`match:${matchId}`, {clockOffset: offset})
  let currentLetter = null
  const counterElement = document.querySelector("#counter")
  const gameFields = document.querySelectorAll('#round input[type="text"]')

  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })

  channel.on("game_start", ({ countdown, letter, round }) => {
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
        addEvents(letter, gameFields, channel)

        // Focus on the first elmeent to make it easier to start playing
        gameFields[0].focus()

        // Actions to perform when round starts
        onRoundStart(letter, channel)
      }
    }, 1000)
  })

  channel.on("round_finished", () => {
    console.log(`round finished!: ${currentLetter}`)
    clearInterval(intervalId)

    onRoundEnd(currentLetter, gameFields, channel)
  })

  channel.on("round_start", ({letter}) => {
    addEvents(letter, gameFields, channel)
    console.log(`round starting ${letter}`)
    clearInterval(intervalId)
    currentLetter = letter
    gameFields.forEach(i => {
      i.classList.remove("disabled")
      i.disabled = false
    })
    onRoundStart(letter, channel)
  })

  channel.on("show_scores", () => {
    console.log("Show scores")
    window.dispatchEvent(new CustomEvent("match:score"))
  })

  channel.on("next_round", ({timeout}) => {
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

  channel.on("in_review", ({category}) => {
    console.log(`channel in_review category: ${category}`)
    onReview(category, channel)
  })

  channel.on("player_activity", (params) => {
    window.dispatchEvent(new CustomEvent("match:onPlayerActivity", {detail: params}))
  })

  channel.on("game_finished", () => {
    console.log("GAME OVER!")
    window.location = "/"
  })

  return channel
}

const handleEnterEvent = (channel, letter, inputs) => {
  return (event => {
    if(event.key === "Enter" && validateFields(letter, inputs)) {
      channel.push("player_finished", {letter})
    }
  })
}

const handleBlurEvent = (channel, letter) => {
  return (event => {
    channel.push("player_activity", {
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

const addEvents = (letter, inputs, channel) => {
  inputs.forEach(input => {
    input.addEventListener("keypress", handleEnterEvent(channel, letter, inputs))
    input.addEventListener("blur", handleBlurEvent(channel, letter))
  })
}

const removeEvents = (letter, inputs, channel) => {
  inputs.forEach(input => {
    removeEventListener("keypress", handleEnterEvent(channel, letter, inputs))
    removeEventListener("blur", handleBlurEvent(channel, letter))
  })
}

const calculateScore = (letter, inputs) =>
  Array.from(inputs).reduce((acc, i) => acc + (isValid(letter, i) ? 100 : 0), 0)

const onRoundStart = (letter, channel) => {
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
      channel.push("round_finished", {letter})
    }
  }, 1000)
}

const onRoundEnd = (letter, inputs, channel) => {
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

  removeEvents(letter, inputs, channel)

  const answers = Object.fromEntries(Array.from(inputs).map(i => [i.dataset.category, i.value]))

  console.log(answers)
  channel.push("report_answers", answers)
}

const onReview = (category, channel) => {
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
