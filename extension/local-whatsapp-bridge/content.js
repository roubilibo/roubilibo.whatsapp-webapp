(() => {
  let lastUnread = -1;
  function numericValue(node) {
    const label = node.getAttribute("aria-label") || "";
    const text = (node.textContent || "").trim();
    const match = `${label} ${text}`.match(/\d[\d,.]*/);
    if (!match) return null;
    const value = Number(match[0].replace(/[,.]/g, ""));
    return Number.isFinite(value) ? value : null;
  }

  function unreadCount() {
    const titleMatch = document.title.match(/(?:^|\s|\()([0-9][0-9,]*)\)?\s*(?:WhatsApp|web\.whatsapp\.com)/i);
    if (titleMatch) return Number(titleMatch[1].replace(/,/g, "")) || 0;

    // WhatsApp's global unread filter is currently rendered as a visible
    // button label such as "Unread 10", without a stable test id.
    const unreadFilter = [...document.querySelectorAll("button, [role=button]")]
      .map((node) => (node.textContent || "").trim().match(/^Unread\s+([0-9][0-9,]*)$/i))
      .find((match) => match);
    if (unreadFilter) return Number(unreadFilter[1].replace(/,/g, "")) || 0;

    const badges = document.querySelectorAll(
      '[data-testid="icon-unread-count"], span[aria-label*="unread" i]'
    );
    const globalBadges = [...badges].filter(
      (node) => !node.closest('[data-testid="cell-frame-container"]')
    );
    const values = globalBadges.map(numericValue).filter((value) => value !== null);
    if (values.length) return Math.max(...values);

    // During a call WhatsApp can replace the chat list with the call screen.
    // No visible unread marker in that view means "unknown", not zero; keep
    // the last count until the chat list returns and can report a real value.
    if (/whatsapp\s+call/i.test(document.title)) return null;

    // A loaded chat sidebar with no unread markers is a confirmed zero. If the
    // sidebar is absent (loading, call, or another transient view), don't
    // overwrite the last known unread count with a guessed zero.
    return document.querySelector("#side") ? 0 : null;
  }

  function publish() {
    const unread = unreadCount();
    if (unread === null) return;
    if (unread === lastUnread) return;
    lastUnread = unread;
    chrome.runtime.sendMessage({ type: "whatsapp-unread", unread });
  }

  new MutationObserver(publish).observe(document.documentElement, {
    subtree: true, childList: true, attributes: true, attributeFilter: ["aria-label"]
  });
  publish();
  setInterval(publish, 2000);
})();
