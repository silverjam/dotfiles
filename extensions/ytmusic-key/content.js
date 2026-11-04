const PORT = 17321;
let ws;

const targets = {
  like: 'ytmusic-like-button-renderer button[aria-label="Like"], ytmusic-like-button-renderer button[aria-label="Unlike"]',
  dislike: 'ytmusic-like-button-renderer button[aria-label="Dislike"], ytmusic-like-button-renderer button[aria-label="Undislike"]',
  repeat: 'ytmusic-player-bar button[aria-label^="Repeat"]',
};

const keys = {
  like: { key: '+', code: 'Equal', shiftKey: true, keyCode: 187 },
  dislike: { key: '-', code: 'Minus', shiftKey: true, keyCode: 189 },
  repeat: { key: 'r', code: 'KeyR', keyCode: 82 },
};

function press(cmd) {
  for (const type of ['keydown', 'keyup'])
    document.dispatchEvent(new KeyboardEvent(type, { ...keys[cmd], bubbles: true }));
}

function run(cmd) {
  if (cmd === 'dislike') {
    const btn = document.querySelector(targets.dislike);
    if (btn) {
      btn.click();
      document.querySelector('ytmusic-player-bar button[aria-label="Next"]')?.click();
    } else {
      press('dislike'); // Shift+minus also skips
    }
    return;
  }
  const el = document.querySelector(targets[cmd]);
  if (el) {
    el.click();
    return;
  }
  press(cmd);
}

function connect() {
  ws = new WebSocket(`ws://127.0.0.1:${PORT}`);
  ws.onmessage = (e) => run(e.data);
  ws.onclose = () => setTimeout(connect, 500);
  ws.onerror = () => ws.close();
}

connect();
