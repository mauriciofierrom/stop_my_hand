import { show, hide, disable, enable, formatTime, resetCountdown } from '../util'
import { components } from './components'

/**
 * @param {string} letter
 * @param {Object} channel - Phoenix channel
 * @param {number} timeoutId
 * @returns {{ removeEvents: function(): void, timeoutId: number }}
 */
export const onRoundStart = (letter, channel, timeoutId) => {
  const duration = 180
  const removeEvents = addEvents(letter, components.gameFields, channel)

  components.gameFields.forEach(enable)
  components.roundTimeout.textContent = formatTime(duration)
  show(components.roundTimeout)
  show(components.gameElement)
  components.gameFields[0].focus()
  components.letterElement.textContent = letter

  const newTimeoutId = resetCountdown(timeoutId, duration,
    d => components.roundTimeout.textContent = formatTime(d),
    () => channel.push("round_finished", { letter })
  )

  return { removeEvents, timeoutId: newTimeoutId }
}

/**
 * @param {string} letter
 * @param {Object} channel - Phoenix channel
 * @param {function(): void} removeEvents
 */
export const onRoundEnd = (letter, channel, removeEvents) => {
  components.letterElement.textContent = `Reviewing - ${letter}`
  components.gameFields.forEach(disable)
  removeEvents()

  const answers = Object.fromEntries(
    Array.from(components.gameFields).map(i => [i.dataset.category, i.value])
  )

  channel.push("report_answers", answers)
}

/**
 * @param {string} category
 * @param {number} timeoutId
 * @returns {number} new timeoutId
 */
export const onReview = (category, timeoutId) => {
  window.dispatchEvent(new CustomEvent("match:review", { detail: { category } }))
  show(components.roundTimeout)

  return resetCountdown(timeoutId, 10,
    d => components.roundTimeout.textContent = formatTime(d),
    () => console.log("answer review timed out!")
  )
}

/**
 * @param {number} timeout
 * @param {number} timeoutId
 * @returns {number} new timeoutId
 */
export const onNextRound = (timeout, timeoutId) => {
  window.dispatchEvent(new CustomEvent("match:reset"))
  hide(components.gameElement)

  return resetCountdown(timeoutId, timeout,
    d => components.roundTimeout.textContent = formatTime(d),
    () => {}
  )
}

const addEvents = (letter, inputs, channel) => {
  const enterHandler = (event) => {
    if (event.key === "Enter" && validateFields(letter, inputs)) {
      channel.push("player_finished", { letter })
    }
  }

  const blurHandler = (event) => {
    channel.push("player_activity", {
      category: event.target.dataset.category,
      letter,
      size: event.target.value.length
    })
  }

  inputs.forEach(input => {
    input.addEventListener("keypress", enterHandler)
    input.addEventListener("blur", blurHandler)
  })

  return () => inputs.forEach(input => {
    input.removeEventListener("keypress", enterHandler)
    input.removeEventListener("blur", blurHandler)
  })
}

const isValid = (letter, input) =>
  input.value && input.value[0].toUpperCase() === letter.toUpperCase()

const validateFields = (letter, inputs) =>
  Array.from(inputs).every(i => isValid(letter, i))
