# YouTube Music key bridge

Install: open `vivaldi://extensions`, enable Developer mode, **Load unpacked**,
and pick this folder. Then reload the YouTube Music PWA once.

The content script listens on `ws://127.0.0.1:17321` for `like` / `repeat`
commands sent by `scripts/vc-ytmusic-{like,dislike,repeat}.sh`.
