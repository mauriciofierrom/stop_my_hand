let Hooks = {}

Hooks.ConfirmInvite = {
  mounted() {
    this.el.addEventListener("click", (event) => {
      event.preventDefault()
      const confirmed = confirm("Are you sure you want to send invite?")
      if(confirmed) {
        const userid = this.el.dataset.userid
        this.pushEvent("invite_friend", { userid })
      }
    })
  }
}

export default Hooks;
