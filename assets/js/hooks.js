let Hooks = {}

Hooks.ConfirmInvite = {
  mounted() {
    console.log("confirm invite")
    this.el.addEventListener("click", (event) => {
      event.preventDefault()
      const confirmed = confirm("Are you sure you want to send invite?")
      if(confirmed) {
        const userid = this.el.dataset.userid
        this.pushEventTo(this.el, "invite_friend", { userid })
      }
    })
  }
}

Hooks.ConfirmInviteAccept = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      event.preventDefault()
      const confirmed = confirm("Are you sure you want to accept invite?")
      if(confirmed) {
        const inviteid = this.el.dataset.inviteid
        this.pushEvent("accept_invite", { inviteid })
      }
    })
  }
}

Hooks.ConfirmFriendRemoval = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      event.preventDefault()
      const confirmed = confirm("Are you sure you want to remove friend?")
      if(confirmed) {
        const userid = this.el.dataset.userid
        this.pushEvent("remove_friend", { userid })
      }
    })
  }
}

Hooks.MatchHook = {
  mounted() {
    console.log("match hook mounted")
    window.addEventListener("match:review", ({detail: payload}) => {
      console.log(`match:review category: ${payload}`)
      this.pushEvent("enable_review", payload)
    })

    window.addEventListener("match:reset", (e) => {
      console.log("match:reset")
      const gameForm = document.querySelector("#round")
      gameForm.reset()
      this.pushEvent("reset", {})
    })

    window.addEventListener("match:score", (e) => {
      console.log("match:score")
      this.pushEvent("show_scores", {})
    })

    window.addEventListener("match:onPlayerActivity", ({detail: payload}) => {
      console.log("player_activity")
      this.pushEvent("player_activity", payload)
    })
  }
}

Hooks.NotificationHover = {
  mounted() {
    console.log("NotificationHover mounted")
    this.el.addEventListener("mouseenter", (e) => {
      console.log(`The notification id: ${this.el.dataset.notificationId}`)
      this.pushEvent("notification_read", { id: this.el.dataset.notificationId })
    })
  }
}

export default Hooks;
