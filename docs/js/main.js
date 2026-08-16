/* menu · lang toggle · works filter · lightbox · video click-to-load */
(function () {
  // menu a scomparsa
  var burger = document.getElementById('burger'), nav = document.getElementById('nav');
  if (burger && nav) {
    var setMenu = function (open) {
      document.body.classList.toggle('nav-open', open);
      burger.setAttribute('aria-expanded', open ? 'true' : 'false');
      burger.setAttribute('aria-label', open ? 'Chiudi il menu' : 'Menu');
    };
    burger.addEventListener('click', function () {
      setMenu(!document.body.classList.contains('nav-open'));
    });
    // toccata una voce, il pannello si chiude da solo
    nav.addEventListener('click', function (e) {
      if (e.target.closest('a')) setMenu(false);
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && document.body.classList.contains('nav-open')) {
        setMenu(false); burger.focus();
      }
    });
    // tornando alla larghezza da computer il menu non deve restare "aperto"
    window.addEventListener('resize', function () {
      if (window.innerWidth > 860) setMenu(false);
    });
  }

  // language
  var btn = document.getElementById('langBtn');
  function applyLang(l) {
    document.documentElement.setAttribute('data-lang', l);
    document.querySelectorAll('[data-lang]').forEach(function (el) {
      if (el === document.documentElement) return;
      el.hidden = el.getAttribute('data-lang') !== l;
    });
    try { localStorage.setItem('gp-lang', l); } catch (e) {}
  }
  var lang = 'it';
  try { lang = localStorage.getItem('gp-lang') || 'it'; } catch (e) {}
  applyLang(lang);
  if (btn) btn.addEventListener('click', function () {
    applyLang((document.documentElement.getAttribute('data-lang') || 'it') === 'it' ? 'en' : 'it');
  });

  // works filter
  var filters = document.getElementById('filters');
  var grid = document.getElementById('worksGrid');
  if (filters && grid) {
    filters.addEventListener('click', function (e) {
      var chip = e.target.closest('.chip'); if (!chip) return;
      filters.querySelectorAll('.chip').forEach(function (c) { c.classList.remove('on'); });
      chip.classList.add('on');
      var f = chip.getAttribute('data-f');
      grid.querySelectorAll('.card').forEach(function (card) {
        card.style.display = (f === '*' || card.getAttribute('data-cat') === f) ? '' : 'none';
      });
    });
    var h = location.hash.slice(1);
    if (h) { var c = filters.querySelector('[data-f="' + h + '"]'); if (c) c.click(); }
  }

  // lightbox
  var lb = document.getElementById('lb'), lbImg = document.getElementById('lbImg'), lbCap = document.getElementById('lbCap');
  // ogni gruppo è una galleria a sé: le frecce restano dentro il gruppo aperto
  var groups = Array.prototype.slice.call(document.querySelectorAll('.gal, .wg-grid, .wg-s-im'))
    .map(function (c) { return Array.prototype.slice.call(c.querySelectorAll('img')); })
    .filter(function (g) { return g.length; });
  var shots = groups.length ? groups[0] : [];
  var idx = 0;
  function show(i) {
    idx = (i + shots.length) % shots.length;
    var im = shots[idx];
    lbImg.src = im.getAttribute('data-full') || im.src;
    var l = document.documentElement.getAttribute('data-lang') || 'it';
    var cap = im.getAttribute(l === 'en' ? 'data-cap-en' : 'data-cap') || '';
    lbCap.textContent = (idx + 1) + ' / ' + shots.length + (cap ? ' · ' + cap : '');
    lb.hidden = false; document.body.style.overflow = 'hidden';
  }
  function hide() { lb.hidden = true; document.body.style.overflow = ''; }
  if (lb && groups.length) {
    groups.forEach(function (g) {
      g.forEach(function (im, i) {
        im.addEventListener('click', function () { shots = g; show(i); });
      });
    });
    document.getElementById('lbX').addEventListener('click', hide);
    document.getElementById('lbP').addEventListener('click', function (e) { e.stopPropagation(); show(idx - 1); });
    document.getElementById('lbN').addEventListener('click', function (e) { e.stopPropagation(); show(idx + 1); });
    lb.addEventListener('click', function (e) { if (e.target === lb || e.target === lbImg) hide(); });
    document.addEventListener('keydown', function (e) {
      if (lb.hidden) return;
      if (e.key === 'Escape') hide();
      if (e.key === 'ArrowLeft') show(idx - 1);
      if (e.key === 'ArrowRight') show(idx + 1);
    });
  }

  // hero video: rispetta prefers-reduced-motion e riparte pulito
  var hv = document.querySelector('video.hero-im');
  if (hv && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    hv.removeAttribute('autoplay'); hv.pause(); hv.currentTime = 0;
  }

  // videos
  document.querySelectorAll('.vid').forEach(function (v) {
    v.addEventListener('click', function () {
      if (v.querySelector('iframe')) return;
      var id = v.getAttribute('data-vid');
      var f = document.createElement('iframe');
      f.src = 'https://www.youtube-nocookie.com/embed/' + id + '?autoplay=1&rel=0';
      f.allow = 'autoplay; encrypted-media; picture-in-picture';
      f.allowFullscreen = true;
      v.innerHTML = ''; v.appendChild(f);
    });
  });
})();
