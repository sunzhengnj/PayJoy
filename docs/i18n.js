const PayJoyDocs = (() => {
  const supportedLanguages = ["zh-Hans", "zh-Hant", "en", "ja", "ko"];

  function normalizeLanguage(input) {
    const value = (input || "").toLowerCase();
    if (!value) return "zh-Hans";
    if (value.startsWith("zh-hant") || value.includes("hant") || value.startsWith("zh-tw") || value.startsWith("zh-hk")) {
      return "zh-Hant";
    }
    if (value.startsWith("zh")) return "zh-Hans";
    if (value.startsWith("ja")) return "ja";
    if (value.startsWith("ko")) return "ko";
    if (value.startsWith("en")) return "en";
    return "zh-Hans";
  }

  const language = (() => {
    const params = new URLSearchParams(window.location.search);
    return normalizeLanguage(params.get("lang") || navigator.language);
  })();

  function withLanguage(path) {
    const url = new URL(path, window.location.href);
    url.searchParams.set("lang", language);
    return `${url.pathname}${url.search}`;
  }

  function setText(id, value) {
    const element = document.getElementById(id);
    if (element) {
      element.textContent = value;
    }
  }

  function setHTML(id, value) {
    const element = document.getElementById(id);
    if (element) {
      element.innerHTML = value;
    }
  }

  function setList(id, items, ordered = false) {
    const element = document.getElementById(id);
    if (!element) return;
    element.innerHTML = items.map((item) => `<li>${item}</li>`).join("");
    if (ordered) {
      element.setAttribute("data-list-type", "ordered");
    }
  }

  function applySharedContent(content) {
    document.documentElement.lang = language;
    document.title = content.title;
    setText("brand", content.brand);
    setText("hero-title", content.heroTitle);
    setText("hero-muted", content.heroMuted);
    if (content.heroMeta) {
      setText("hero-meta", content.heroMeta);
    }
    if (content.navLabel) {
      const nav = document.getElementById("page-nav");
      if (nav) nav.setAttribute("aria-label", content.navLabel);
    }

    const navItems = [
      ["nav-index", "index.html", content.nav.index],
      ["nav-privacy", "privacy.html", content.nav.privacy],
      ["nav-terms", "terms.html", content.nav.terms],
      ["nav-support", "support.html", content.nav.support],
      ["nav-delete", "delete-account.html", content.nav.deleteAccount]
    ];

    navItems.forEach(([id, path, label]) => {
      const element = document.getElementById(id);
      if (!element) return;
      element.textContent = label;
      element.setAttribute("href", withLanguage(path));
    });

    const footer = document.getElementById("footer-text");
    if (footer && content.footer) {
      footer.textContent = content.footer;
    }
  }

  return {
    language,
    supportedLanguages,
    normalizeLanguage,
    withLanguage,
    setText,
    setHTML,
    setList,
    applySharedContent
  };
})();
