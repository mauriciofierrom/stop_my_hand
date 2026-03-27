/**
 * Disables a form element and adds the "disabled" CSS class.
 * @param {HTMLElement} element
 */
export const disable = (element) => {
  element.classList.add("disabled")
  element.disabled = true
}

/**
 * Enables a form element and adds the "enabled" CSS class.
 * @param {HTMLElement} element
 */
export const enable = (element) => {
  element.classList.remove("disabled")
  element.disabled = false
}

/**
 * Shows an element by removing the "hidden" CSS class.
 * @param {HTMLElement} element
 */
export const show = (element) => {
  element.classList.remove("hidden")
}

/**
 * Hides an element by adding the "hidden" CSS class.
 * @param {HTMLElement} element
 */
export const hide = (element) => {
  element.classList.add("hidden")
}

/**
 * Clears any existing countdown and starts a new one.
 * @param {number} timeoutId - Existing interval ID to clear.
 * @param {number} duration - Countdown duration in seconds.
 * @param {function(number): void} action - Called each tick with the remaining duration.
 * @param {function(): void} onEnd - Called when the countdown reaches zero.
 * @returns {number} The new interval ID.
 */
export const resetCountdown = (timeoutId, duration, action = _ => {}, onEnd = () => {}) => {
  clearInterval(timeoutId)
  timeoutId = setInterval(() => {
    duration -= 1
    action(duration)
    if(duration === 0) {
      clearInterval(timeoutId)
      onEnd()
    }
  }, 1000)
  return timeoutId
}

/**
 * Formats a duration in seconds as MM:SS.
 * @param {number} seconds
 * @returns {string}
 */
export const formatTime = (seconds) => {
  const toMinute = (seconds) => Math.floor(seconds / 60)
  const toSecondsLeft = (seconds) => seconds % 60
  return `${toMinute(seconds).toString().padStart(2, '0')}:${toSecondsLeft(seconds).toString().padStart(2, '0')}`
}
