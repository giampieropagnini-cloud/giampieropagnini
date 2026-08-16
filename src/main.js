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
  var shots = Array.prototype.slice.call(document.querySelectorAll('.gal .ph img'));
  var idx = 0;
  function show(i) {
    idx = (i + shots.length) % shots.length;
    lbImg.src = shots[idx].src;
    lbCap.textContent = (idx + 1) + ' / ' + shots.length;
    lb.hidden = false; document.body.style.overflow = 'hidden';
  }
  function hide() { lb.hidden = true; document.body.style.overflow = ''; }
  if (lb && shots.length) {
    shots.forEach(function (im, i) { im.addEventListener('click', function () { show(i); }); });
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
