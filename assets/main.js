const COMMANDS = {
  linux: "curl -fsSL https://raw.githubusercontent.com/mozzarellabio/agnt/main/install.sh | sh",
  windows: "irm https://raw.githubusercontent.com/mozzarellabio/agnt/main/install.ps1 | iex",
}
const NOTES = {
  linux: "Run in any shell. Installs the agnt binary for Linux.",
  windows: "Run in PowerShell. Installs the agnt binary for Windows.",
}
const MODES = {
  ask: ["apply these 2 changes? [y/n]", "ask: confirms before every edit or command."],
  auto: ["applying 2 changes… done. running tests next.", "auto: edits and runs commands on its own; you watch, and undo if needed."],
  plan: ["plan ready: 2 files. approve to start.", "plan: reads and proposes; nothing changes until you approve."],
  free: ["applied 2 changes. running tests.", "free: no confirmations at all, for sandboxes and throwaway branches."],
}

const $$ = (sel) => [...document.querySelectorAll(sel)]
const live = document.getElementById("live")
let os = "linux"
let timer

function press(buttons, active) {
  for (const b of buttons) b.setAttribute("aria-pressed", String(b === active))
}

function setOs(next) {
  os = next
  for (const g of $$(".os")) press([...g.children], g.querySelector(`[data-os="${next}"]`))
  for (const el of $$("[data-cmd]")) el.textContent = COMMANDS[next]
  for (const el of $$(".pr")) el.textContent = next === "windows" ? "PS> " : "$ "
  for (const el of $$("[data-osnote]")) el.textContent = NOTES[next]
  setCopied("")
}

function setCopied(state) {
  const label = state === "ok" ? "Copied" : state === "sel" ? "Press Ctrl+C" : "Copy"
  for (const el of $$("[data-copy-label]")) el.textContent = label
  live.textContent = state === "ok" ? "Install command copied." : state === "sel" ? "Install command selected. Press Control C to copy." : ""
  clearTimeout(timer)
  if (state) timer = setTimeout(() => setCopied(""), 2000)
}

async function copy(button) {
  const target = button.closest(".inst").querySelector("[data-cmd]")
  try {
    await navigator.clipboard.writeText(COMMANDS[os])
    setCopied("ok")
  } catch {
    const range = document.createRange()
    range.selectNodeContents(target)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
    setCopied("sel")
  }
}

function setMode(id) {
  const [hint, desc] = MODES[id]
  press($$("[data-mode]"), document.querySelector(`[data-mode="${id}"]`))
  document.getElementById("mode-name").textContent = id
  document.getElementById("mode-hint").textContent = hint
  document.getElementById("mode-desc").textContent = desc
}

function setSkin(id) {
  press($$("[data-skin].segb"), document.querySelector(`.segb[data-skin="${id}"]`))
  document.getElementById("term").dataset.skin = id
  document.getElementById("skin-name").textContent = id
}

for (const b of $$("[data-os]")) b.addEventListener("click", () => setOs(b.dataset.os))
for (const b of $$("[data-copy]")) b.addEventListener("click", () => copy(b))
for (const b of $$("[data-mode]")) b.addEventListener("click", () => setMode(b.dataset.mode))
for (const b of $$(".segb[data-skin]")) b.addEventListener("click", () => setSkin(b.dataset.skin))

const platform = `${navigator.userAgentData?.platform ?? navigator.platform ?? ""} ${navigator.userAgent ?? ""}`
if (/windows|win32|win64/i.test(platform)) setOs("windows")

const qr = document.getElementById("qr")
if (qr) {
  const N = 21
  const finder = (x, y) => {
    for (const [ox, oy] of [[0, 0], [N - 7, 0], [0, N - 7]]) {
      const dx = x - ox, dy = y - oy
      if (dx >= 0 && dx < 7 && dy >= 0 && dy < 7) return Math.max(Math.abs(dx - 3), Math.abs(dy - 3)) !== 2
      if (dx >= -1 && dx < 8 && dy >= -1 && dy < 8) return false
    }
  }
  let seed = 7
  const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff
  for (let y = 0; y < N; y++)
    for (let x = 0; x < N; x++) {
      const cell = document.createElement("i")
      const f = finder(x, y)
      if (!(f === undefined ? rnd() > 0.5 : f)) cell.style.background = "transparent"
      qr.append(cell)
    }
}
