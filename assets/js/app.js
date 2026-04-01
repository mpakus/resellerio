// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {Hooks as BackpexHooks} from "backpex"
import {hooks as colocatedHooks} from "phoenix-colocated/reseller"
import topbar from "../vendor/topbar"
import Sortable from "../vendor/sortable.min.js"

const ClipboardButton = {
  mounted() {
    this.labelTarget = this.el.querySelector("[data-copy-label]") || this.el
    this.defaultLabel = this.el.dataset.copyDefaultLabel || this.labelTarget.textContent.trim()
    this.successLabel = this.el.dataset.copySuccessLabel || "Copied"
    this.errorLabel = this.el.dataset.copyErrorLabel || "Copy failed"
    this.setState("idle")

    this.handleClick = async event => {
      event.preventDefault()
      this.setState("copying")

      const text = this.resolveText()

      if (text === "") {
        this.setFeedback(this.errorLabel, "error")
        return
      }

      try {
        await copyText(text)
        this.setFeedback(this.successLabel, "success")
      } catch (_error) {
        this.setFeedback(this.errorLabel, "error")
      }
    }

    this.el.addEventListener("click", this.handleClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
    clearTimeout(this.resetTimer)
  },

  resolveText() {
    const copyTarget = this.el.dataset.copyTarget

    if (copyTarget) {
      const target = document.querySelector(copyTarget)

      if (!target) {
        return ""
      }

      if ("value" in target && typeof target.value === "string") {
        return target.value.trim()
      }

      return (target.innerText || target.textContent || "").trim()
    }

    return (this.el.dataset.copyText || "").trim()
  },

  setFeedback(label, state) {
    this.labelTarget.textContent = label
    this.el.setAttribute("title", label)
    this.el.setAttribute("aria-label", label)
    this.setState(state)
    clearTimeout(this.resetTimer)

    this.resetTimer = window.setTimeout(() => {
      this.labelTarget.textContent = this.defaultLabel
      this.el.setAttribute("title", this.defaultLabel)
      this.el.setAttribute("aria-label", this.defaultLabel)
      this.setState("idle")
    }, 1400)
  },

  setState(state) {
    this.el.dataset.copyState = state
  }
}

async function copyText(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }

  const textarea = document.createElement("textarea")
  textarea.value = text
  textarea.setAttribute("readonly", "")
  textarea.style.position = "absolute"
  textarea.style.left = "-9999px"
  document.body.appendChild(textarea)
  textarea.select()
  document.execCommand("copy")
  textarea.remove()
}

const ScrollReveal = {
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            entry.target.classList.add("revealed")
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    )
    this.el.querySelectorAll(".reveal, .reveal-left, .reveal-right").forEach(el => {
      this.observer.observe(el)
    })
    if (this.el.classList.contains("reveal") || this.el.classList.contains("reveal-left") || this.el.classList.contains("reveal-right")) {
      this.observer.observe(this.el)
    }
  },
  destroyed() { this.observer.disconnect() }
}

let scrollRevealActive = false

function revealCheck() {
  const vh = window.innerHeight
  document.querySelectorAll(".reveal, .reveal-left, .reveal-right").forEach(el => {
    if (el.classList.contains("revealed")) return
    const rect = el.getBoundingClientRect()
    if (rect.top < vh + 20 && rect.bottom > -20) {
      el.classList.add("revealed")
    }
  })
}

function setupScrollReveal() {
  document.querySelectorAll(".reveal, .reveal-left, .reveal-right").forEach(el => {
    el.classList.add("reveal-ready")
  })
  revealCheck()
  if (!scrollRevealActive) {
    scrollRevealActive = true
    window.addEventListener("scroll", revealCheck, { passive: true })
  }
}

document.addEventListener("DOMContentLoaded", setupScrollReveal)
let scrollRevealInitialized = false
window.addEventListener("phx:page-loading-stop", () => {
  if (!scrollRevealInitialized) {
    scrollRevealInitialized = true
    setTimeout(setupScrollReveal, 100)
  }
})
window.addEventListener("phx:navigate", () => {
  scrollRevealInitialized = false
  scrollRevealActive = false
  setTimeout(setupScrollReveal, 120)
})

const CountUp = {}

const SortableGallery = {
  mounted() {
    this.sortable = new Sortable(this.el, {
      animation: 150,
      ghostClass: "opacity-40",
      chosenClass: "scale-105",
      dragClass: "shadow-xl",
      handle: "[data-drag-handle]",
      onEnd: (evt) => {
        const items = Array.from(this.el.querySelectorAll("[data-image-id]"))
        const ids = items.map(el => parseInt(el.dataset.imageId, 10))
        this.pushEvent("reorder_storefront_images", {image_ids: ids})
      }
    })
  },
  destroyed() {
    if (this.sortable) this.sortable.destroy()
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {ClipboardButton, ScrollReveal, CountUp, SortableGallery, ...colocatedHooks, ...BackpexHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
