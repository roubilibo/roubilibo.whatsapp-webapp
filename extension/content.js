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

    const header = document.querySelector("#side > header, #side header");
    if (header) {
      const values = [...header.querySelectorAll("*")]
        .filter((node) => node.children.length === 0)
        .map(numericValue).filter((value) => value !== null);
      if (values.length) return Math.max(...values);
    }

    const badges = document.querySelectorAll(
      '[data-testid="icon-unread-count"], span[aria-label*="unread" i]'
    );
    const globalBadges = [...badges].filter(
      (node) => !node.closest('[data-testid="cell-frame-container"]')
    );
    const values = globalBadges.map(numericValue).filter((value) => value !== null);
    if (values.length) return Math.max(...values);

    // Current WhatsApp versions may render the left-rail global count as a
    // plain visible leaf number without an aria-label or test id.
    const standaloneNumbers = [...document.querySelectorAll("*")]
      .filter((node) => {
        if (node.children.length > 0 || !node.getClientRects().length) return false;
        if (node.closest(
          '[data-testid="cell-frame-container"], [data-testid="conversation-panel-wrapper"], [data-testid="conversation-panel-body"]'
        )) return false;
        return /^\d{1,2}$/.test((node.textContent || "").trim());
      })
      .map(numericValue).filter((value) => value !== null);
    if (standaloneNumbers.length) return Math.max(...standaloneNumbers);

    return globalBadges.length ? 1 : 0;
  }

  function publish() {
    const unread = unreadCount();
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
