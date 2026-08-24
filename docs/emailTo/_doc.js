
const q = document.getElementById('filter');
if (q) {
  const rows = [...document.querySelectorAll('tr.fn')];
  q.addEventListener('input', () => {
    const t = q.value.trim().toLowerCase();
    rows.forEach(r => r.classList.toggle('hide', t && !r.dataset.k.includes(t)));
    document.querySelectorAll('.tw').forEach(w => {
      const body = w.querySelector('tbody');
      if (!body) return;
      const any = [...body.querySelectorAll('tr')].some(r => !r.classList.contains('hide'));
      const h = w.previousElementSibling;
      w.classList.toggle('hide', !any);
      if (h && h.tagName === 'H3') h.classList.toggle('hide', !any);
    });
  });
}
/*  Which sidebar entry is lit.  An IntersectionObserver was the wrong
    instrument: one click crosses several headings at once, every one of them
    arrives in a single callback, and the last entry processed won - so the
    highlight settled one or two sections past the one that was clicked, and
    the page looked as though it had jumped there.  Position is the question,
    so ask position.  */
const links = [...document.querySelectorAll('.nav__l a')];
if (links.length) {
  const byId  = new Map(links.map(a => [a.getAttribute('href').slice(1), a]));
  const marks = [...document.querySelectorAll('h2[id],h3[id]')].filter(h => byId.has(h.id));
  const light = a => links.forEach(l => l.classList.toggle('on', l === a));
  let held = null, holdUntil = 0, queued = false;

  function spy() {
    queued = false;
    if (held) { light(held); return; }
    let cur = marks[0];
    for (const h of marks) {
      if (h.getBoundingClientRect().top <= 120) cur = h; else break;
    }
    //  the foot of the page belongs to the last section, however short it is
    if (innerHeight + scrollY >= document.documentElement.scrollHeight - 2)
      cur = marks[marks.length - 1];
    if (cur) light(byId.get(cur.id));
  }

  //  a click owns the highlight until the scroll it started has landed
  links.forEach(a => a.addEventListener('click', () => {
    held = a; holdUntil = performance.now() + 700; light(a);
  }));
  const later = () => { if (!queued) { queued = true; requestAnimationFrame(spy); } };
  addEventListener('scroll', () => {
    if (held && performance.now() > holdUntil) held = null;
    later();
  }, {passive: true});
  addEventListener('resize', later);
  if (marks.length) spy();
}
