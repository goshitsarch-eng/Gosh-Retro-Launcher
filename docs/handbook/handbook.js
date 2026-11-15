/* Program Manager handbook: progressive enhancement.
   The page reads fully without this script. It adds search, filters, deep-link reveal,
   copy buttons, a screenshot dialog, a theme switch, and print preparation.
   Classic script, no modules, no network access, so it runs from file://. */
(function () {
  'use strict';

  var FILTER_GROUPS = ['audience', 'topic', 'platform', 'status', 'severity'];
  var THEME_KEY = 'pm-handbook-theme';
  var MOBILE_QUERY = '(max-width: 860px)';

  var doc = document;
  var root = doc.documentElement;
  var entries = [];
  var chapters = [];
  var searchInput = doc.getElementById('search');
  var resultText = doc.getElementById('result-text');
  var chipList = doc.getElementById('chips');
  var noResults = doc.getElementById('no-results');
  var sidebar = doc.getElementById('sidebar');
  var navToggle = doc.getElementById('nav-toggle');
  var themeButton = doc.getElementById('theme-toggle');
  var copyStatus = doc.getElementById('copy-status');
  var dialog = doc.getElementById('shot-dialog');
  var shotImage = doc.getElementById('shot-image');
  var shotCaption = doc.getElementById('shot-caption');
  var shotClose = doc.getElementById('shot-close');
  var lastTrigger = null;
  var debounceTimer = null;
  var printSnapshot = null;

  root.className = (root.className ? root.className + ' ' : '') + 'js';

  function words(value) {
    return String(value || '').toLowerCase().split(/\s+/).filter(Boolean);
  }

  function entryText(el) {
    var copy = el.cloneNode(true);
    copy.querySelectorAll('.copy, .shot-hint, script, style').forEach(function (n) { n.remove(); });
    return copy.textContent.replace(/\s+/g, ' ').toLowerCase();
  }

  function checkboxes(group) {
    return Array.prototype.slice.call(
      doc.querySelectorAll('input[type="checkbox"][data-group="' + group + '"]')
    );
  }

  function selected(group) {
    return checkboxes(group).filter(function (c) { return c.checked; }).map(function (c) { return c.value; });
  }

  function labelFor(input) {
    var label = input.closest('label');
    return label ? label.textContent.trim() : input.value;
  }

  // Build the index once from the DOM. Each entry carries its own attributes and cached search text.
  function buildIndex() {
    entries = Array.prototype.slice.call(doc.querySelectorAll('article.entry')).map(function (el) {
      var section = el.closest('section.chapter');
      return {
        el: el,
        chapter: section,
        text: entryText(el),
        audience: words(el.getAttribute('data-audience')),
        topic: words(el.getAttribute('data-topic')),
        platform: words(el.getAttribute('data-platform')),
        status: words(el.getAttribute('data-status')),
        severity: words(el.getAttribute('data-severity'))
      };
    });
    chapters = Array.prototype.slice.call(doc.querySelectorAll('section.chapter')).map(function (section) {
      var link = doc.querySelector('.toc a[href="#' + section.id + '"]');
      return {
        section: section,
        link: link,
        item: link ? link.closest('li') : null,
        count: link ? link.querySelector('.count') : null,
        total: section.querySelectorAll('article.entry').length
      };
    });
  }

  function matchesGroup(entry, group, chosen) {
    if (!chosen.length) return true;
    var values = entry[group];
    if (group === 'platform' && values.indexOf('all') !== -1) return true;
    if (group === 'severity' && !values.length) return false;
    return values.some(function (v) { return chosen.indexOf(v) !== -1; });
  }

  function matchesSearch(entry, tokens) {
    for (var i = 0; i < tokens.length; i += 1) {
      if (entry.text.indexOf(tokens[i]) === -1) return false;
    }
    return true;
  }

  function renderChips(query, active) {
    chipList.innerHTML = '';
    if (query.trim()) {
      chipList.appendChild(makeChip('Search: "' + query.trim() + '"', function () {
        searchInput.value = '';
        applyFilters();
        searchInput.focus();
      }));
    }
    FILTER_GROUPS.forEach(function (group) {
      checkboxes(group).forEach(function (box) {
        if (!box.checked) return;
        chipList.appendChild(makeChip(group.charAt(0).toUpperCase() + group.slice(1) + ': ' + labelFor(box), function () {
          box.checked = false;
          applyFilters();
          box.focus();
        }));
      });
    });
    chipList.hidden = chipList.childNodes.length === 0;
    doc.getElementById('reset-all').disabled = !active;
    doc.getElementById('reset-filters').disabled = !active;
  }

  function makeChip(text, onRemove) {
    var chip = doc.createElement('span');
    chip.className = 'chip';
    chip.appendChild(doc.createTextNode(text));
    var button = doc.createElement('button');
    button.type = 'button';
    button.setAttribute('aria-label', 'Remove filter: ' + text);
    button.textContent = '×';
    button.addEventListener('click', onRemove);
    chip.appendChild(button);
    return chip;
  }

  // Applies search and filters together (AND across the search box and every filter group,
  // OR within one group). Counts, chapter visibility, and navigation are derived from the same result.
  function applyFilters() {
    var query = searchInput ? searchInput.value : '';
    var tokens = words(query);
    var chosen = {};
    FILTER_GROUPS.forEach(function (g) { chosen[g] = selected(g); });
    var active = tokens.length > 0 || FILTER_GROUPS.some(function (g) { return chosen[g].length > 0; });

    var visibleCount = 0;
    entries.forEach(function (entry) {
      var show = matchesSearch(entry, tokens);
      FILTER_GROUPS.forEach(function (g) {
        if (show && !matchesGroup(entry, g, chosen[g])) show = false;
      });
      entry.el.hidden = !show;
      if (show) {
        visibleCount += 1;
        if (tokens.length) openMatchingDetails(entry.el, tokens);
      }
    });

    chapters.forEach(function (c) {
      var visible = Array.prototype.slice.call(c.section.querySelectorAll('article.entry'))
        .filter(function (el) { return !el.hidden; }).length;
      var hideChapter = c.total > 0 && visible === 0;
      c.section.hidden = hideChapter;
      if (c.item) c.item.hidden = hideChapter;
      if (c.count) c.count.textContent = active ? visible + ' of ' + c.total : String(c.total);
    });

    var total = entries.length;
    resultText.textContent = active
      ? 'Showing ' + visibleCount + ' of ' + total + ' entries'
      : 'All ' + total + ' entries';
    noResults.hidden = visibleCount !== 0;
    renderChips(query, active);
  }

  // A search hit inside a collapsed <details> opens that <details> so the hit is visible.
  function openMatchingDetails(entryEl, tokens) {
    entryEl.querySelectorAll('details').forEach(function (d) {
      if (d.open) return;
      var text = d.textContent.replace(/\s+/g, ' ').toLowerCase();
      var hit = tokens.every(function (t) { return text.indexOf(t) !== -1; });
      if (hit) d.open = true;
    });
  }

  function clearAll() {
    if (searchInput) searchInput.value = '';
    FILTER_GROUPS.forEach(function (g) {
      checkboxes(g).forEach(function (c) { c.checked = false; });
    });
  }

  function revealHash() {
    var id = decodeURIComponent(window.location.hash.slice(1));
    if (!id) return;
    var target = doc.getElementById(id);
    if (!target) return;
    var hidden = target.closest('[hidden]');
    if (hidden) {
      clearAll();
      applyFilters();
    }
    var d = target.closest('details');
    while (d) {
      d.open = true;
      d = d.parentElement ? d.parentElement.closest('details') : null;
    }
    target.scrollIntoView({ block: 'start' });
    if (/^H[1-6]$/.test(target.tagName)) {
      target.setAttribute('tabindex', '-1');
      target.focus({ preventScroll: true });
    }
  }

  function setCopyStatus(text) {
    if (copyStatus) copyStatus.textContent = text;
  }

  function fallbackCopy(text) {
    var area = doc.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.top = '-1000px';
    doc.body.appendChild(area);
    area.select();
    var ok = false;
    try { ok = doc.execCommand('copy'); } catch (err) { ok = false; }
    doc.body.removeChild(area);
    return ok;
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).then(function () { return true; }, function () {
        return fallbackCopy(text);
      });
    }
    return Promise.resolve(fallbackCopy(text));
  }

  function wireCopyButtons() {
    doc.querySelectorAll('.codeblock .copy').forEach(function (button) {
      var block = button.closest('.codeblock');
      var code = block ? block.querySelector('pre code') : null;
      if (!code) return;
      var original = button.textContent;
      button.addEventListener('click', function () {
        copyText(code.textContent.replace(/\s+$/, '')).then(function (ok) {
          button.textContent = ok ? 'Copied' : 'Copy failed';
          button.setAttribute('data-state', ok ? 'copied' : 'failed');
          setCopyStatus(ok ? 'Command copied to the clipboard.' : 'Copy failed. Select the text and copy it manually.');
          window.setTimeout(function () {
            button.textContent = original;
            button.removeAttribute('data-state');
          }, 1800);
        });
      });
    });
  }

  function wireLightbox() {
    if (!dialog || typeof dialog.showModal !== 'function') return;
    doc.querySelectorAll('a.shot').forEach(function (link) {
      link.addEventListener('click', function (event) {
        event.preventDefault();
        lastTrigger = link;
        var img = link.querySelector('img');
        shotImage.src = link.getAttribute('href');
        shotImage.alt = img ? img.alt : '';
        shotCaption.textContent = link.getAttribute('data-caption') || (img ? img.alt : '');
        dialog.showModal();
        shotClose.focus();
      });
    });
    shotClose.addEventListener('click', function () { dialog.close(); });
    dialog.addEventListener('click', function (event) {
      if (event.target === dialog) dialog.close();
    });
    dialog.addEventListener('close', function () {
      shotImage.removeAttribute('src');
      if (lastTrigger) lastTrigger.focus();
    });
  }

  function storedTheme() {
    try {
      var value = window.localStorage.getItem(THEME_KEY);
      return value === 'light' || value === 'dark' ? value : 'auto';
    } catch (err) {
      return 'auto';
    }
  }

  function saveTheme(value) {
    try {
      if (value === 'auto') window.localStorage.removeItem(THEME_KEY);
      else window.localStorage.setItem(THEME_KEY, value);
    } catch (err) { /* storage unavailable: the choice lasts for this page only */ }
  }

  function applyTheme(value) {
    if (value === 'light' || value === 'dark') root.setAttribute('data-theme', value);
    else root.removeAttribute('data-theme');
    if (themeButton) {
      var labels = { auto: 'Theme: automatic', light: 'Theme: light', dark: 'Theme: dark' };
      themeButton.textContent = labels[value];
      themeButton.setAttribute('data-theme-choice', value);
    }
  }

  function wireTheme() {
    if (!themeButton) return;
    applyTheme(storedTheme());
    themeButton.addEventListener('click', function () {
      var order = ['auto', 'light', 'dark'];
      var next = order[(order.indexOf(themeButton.getAttribute('data-theme-choice')) + 1) % order.length];
      saveTheme(next);
      applyTheme(next);
    });
  }

  function wireNavToggle() {
    if (!navToggle || !sidebar) return;
    navToggle.addEventListener('click', function () {
      var open = !sidebar.classList.contains('is-open');
      sidebar.classList.toggle('is-open', open);
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    sidebar.addEventListener('click', function (event) {
      if (event.target.closest('a') && window.matchMedia(MOBILE_QUERY).matches) {
        sidebar.classList.remove('is-open');
        navToggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  function setAllDetails(open) {
    doc.querySelectorAll('details').forEach(function (d) {
      if (!d.closest('[hidden]')) d.open = open;
    });
  }

  // Printing shows the complete manual: filters are cleared for the print, and every <details> opens.
  function prepareForPrint() {
    printSnapshot = {
      query: searchInput ? searchInput.value : '',
      checked: []
    };
    FILTER_GROUPS.forEach(function (g) {
      checkboxes(g).forEach(function (c) {
        if (c.checked) printSnapshot.checked.push(c);
      });
    });
    clearAll();
    applyFilters();
    doc.querySelectorAll('details').forEach(function (d) {
      d.setAttribute('data-print-open', d.open ? 'yes' : 'no');
      d.open = true;
    });
  }

  function restoreAfterPrint() {
    doc.querySelectorAll('details').forEach(function (d) {
      if (d.getAttribute('data-print-open') === 'no') d.open = false;
      d.removeAttribute('data-print-open');
    });
    if (printSnapshot) {
      if (searchInput) searchInput.value = printSnapshot.query;
      printSnapshot.checked.forEach(function (c) { c.checked = true; });
      printSnapshot = null;
      applyFilters();
    }
  }

  function wireEvents() {
    if (searchInput) {
      searchInput.addEventListener('input', function () {
        window.clearTimeout(debounceTimer);
        debounceTimer = window.setTimeout(applyFilters, 120);
      });
      searchInput.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && searchInput.value) {
          event.preventDefault();
          searchInput.value = '';
          applyFilters();
        }
      });
    }
    doc.querySelectorAll('input[type="checkbox"][data-group]').forEach(function (box) {
      box.addEventListener('change', applyFilters);
    });
    ['reset-all', 'reset-filters', 'reset-filters-side'].forEach(function (id) {
      var button = doc.getElementById(id);
      if (!button) return;
      button.addEventListener('click', function () {
        clearAll();
        applyFilters();
        if (searchInput) searchInput.focus();
      });
    });
    var expand = doc.getElementById('expand-all');
    var collapse = doc.getElementById('collapse-all');
    if (expand) expand.addEventListener('click', function () { setAllDetails(true); });
    if (collapse) collapse.addEventListener('click', function () { setAllDetails(false); });
    var printButton = doc.getElementById('print-button');
    if (printButton) printButton.addEventListener('click', function () { window.print(); });
    window.addEventListener('hashchange', revealHash);
    window.addEventListener('beforeprint', prepareForPrint);
    window.addEventListener('afterprint', restoreAfterPrint);
  }

  function init() {
    buildIndex();
    wireCopyButtons();
    wireLightbox();
    wireTheme();
    wireNavToggle();
    wireEvents();
    applyFilters();
    if (window.location.hash) revealHash();
  }

  if (doc.readyState === 'loading') {
    doc.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
