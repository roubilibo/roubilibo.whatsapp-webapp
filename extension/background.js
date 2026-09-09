let nativePort = null;

function sendUnread(unread) {
  if (!nativePort) {
    nativePort = chrome.runtime.connectNative("com.roubilibo.whatsapp_unread");
    nativePort.onDisconnect.addListener(() => { nativePort = null; });
  }
  nativePort.postMessage({ unread: Math.max(0, Number(unread) || 0) });
}

chrome.runtime.onMessage.addListener((message) => {
  if (message && message.type === "whatsapp-unread") sendUnread(message.unread);
});
