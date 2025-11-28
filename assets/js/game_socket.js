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
socket.connect()

// Now that you are connected, you can join channels with a topic.
// Let's assume you have a channel with a topic named `room` and the
// subtopic is its id - in this case 42:

export function createMatch({matchId, timestamp}) {
  const offset = Math.abs(Date.now() - timestamp)
  let channel = socket.channel(`match:${matchId}`, {clockOffset: offset})
  const gameFields = document.querySelectorAll('#round input[type="text"]')
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })
  channel.on("game_start", ({ countdown, letter, round }) => {
    console.log(`GAME START - Countdown: ${countdown}. First letter: ${letter}`)
    let counter = countdown
    const intervalId = setInterval(() => {
      counter--
      if(counter > 0) {
        document.querySelector("#counter").innerHTML = counter
      } else {
        clearInterval(intervalId)

        // Hide counter
        document.querySelector("#counter").classList.add("hidden")

        // Show game element
        const gameElement = document.querySelector("#game")
        gameElement.classList.remove("hidden")

        // Pick new game letter
        const letterElement = document.querySelector("#letter")

        // Set the letter element
        letterElement.innerHTML = `${letter}`
        addEvents(letter, gameFields, channel)

        // Actions to perform when round starts
        onRoundStart(letter, channel)
      }
    }, 1000)
  })
  channel.on("round_finished", ({letter}) => {
    onRoundEnd(letter, gameFields, channel)
  })

  return channel
}

const handleEnterEvent = (channel, letter, inputs) => {
  return (event => {
    if(event.key === "Enter" && validate(letter, inputs)) {
      channel.push("player_finished", {letter})
    }
  })
}

const isValid = (letter, input) =>
      input.value && input.value[0].toUpperCase() === letter.toUpperCase()

const validate = (letter, inputs) =>
  Array.from(inputs).every(i => isValid(letter, i))

const addEvents = (letter, inputs, channel) => {
  inputs.forEach(input =>
    input.addEventListener("keypress", handleEnterEvent(channel, letter, inputs)))
}

const removeEvents = (letter, inputs, channel) => {
  inputs.forEach(input => removeEventListener("keypress", handleEnterEvent(channel, letter, inputs)))
}

const calculateScore = (letter, inputs) =>
  Array.from(inputs).reduce((acc, i) => acc + (isValid(letter, i) ? 100 : 0), 0)

const onRoundEnd = (letter, inputs, channel) => {
  console.log("onRoundEnd")
  const score = calculateScore(letter, inputs)
  inputs.forEach(i => {
    i.classList.add("disabled")
    i.value = ""
    i.disabled = true
  })
  removeEvents(letter, inputs, channel)
  alert(`Score: ${score}`)
}

const onRoundStart = (letter, channel) => {
  const roundTimeout = document.querySelector('#round-countdown')
  const toMinute = (seconds) => Math.floor(seconds / 60)
  const toSecondsLeft = (seconds) => seconds % 60
  const formatTime = (seconds) => `${toMinute(seconds).toString().padStart(2, '0')}:${toSecondsLeft(seconds).toString().padStart(2, '0')}`
  let countdown = 180

  roundTimeout.innerHTML = formatTime(countdown)
  roundTimeout.classList.remove("hidden")

  setInterval(() => {
    countdown -= 1
    roundTimeout.innerHTML = formatTime(countdown)

    if(countdown === 0) {
      channel.push("round_finished", {letter})
    }
  }, 1000)
}

export default socket
