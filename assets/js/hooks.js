let Hooks = {}

Hooks.ConfirmInvite = {
  mounted() {
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
      console.log("match:review")
      console.log(payload)
      this.pushEvent("enable_review", payload)
    })
  }
}

export default Hooks;
