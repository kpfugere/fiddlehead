// show/hide nav after hero, track active section
const nav = document.getElementById('main-nav');
const hero = document.getElementById('hero');
const sections = document.querySelectorAll('section[id]');
const navLinks = document.querySelectorAll('.nav-link[data-section]');

if (nav && hero) {
  // show nav after scrolling past hero
  const heroObserver = new IntersectionObserver(
    ([entry]) => {
      if (entry.isIntersecting) {
        nav.classList.add('nav-hidden');
        nav.classList.remove('nav-visible');
      } else {
        nav.classList.remove('nav-hidden');
        nav.classList.add('nav-visible');
      }
    },
    { threshold: 0 }
  );
  heroObserver.observe(hero);

  // active section tracking
  const sectionObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          const id = entry.target.id;
          navLinks.forEach((link) => {
            link.classList.toggle('active', link.dataset.section === id);
          });
        }
      });
    },
    { threshold: 0.3, rootMargin: '-52px 0px -40% 0px' }
  );

  sections.forEach((section) => sectionObserver.observe(section));
}

// frog eye tracking + idle look-around + blink
const frogIcon = document.querySelector('.hero-icon');
if (frogIcon && window.matchMedia('(pointer: fine)').matches) {
  const pupils = document.querySelectorAll('.frog-pupil-left, .frog-pupil-right');
  let idleTimer = null;
  let idleDriftTimer = null;
  let isIdle = false;

  // helper: set pupil offset
  function setPupilOffset(ox, oy, slow) {
    pupils.forEach((pupil) => {
      pupil.style.transition = slow
        ? 'transform 0.8s ease-in-out, r 0.3s ease-out'
        : 'transform 0.15s ease-out, r 0.3s ease-out';
      pupil.style.transform = `translate(${ox}px, ${oy}px)`;
    });
  }

  // idle: drift gaze to random positions
  function startIdleDrift() {
    isIdle = true;
    function drift() {
      const maxOffset = 3;
      const ox = Math.round((Math.random() * 2 - 1) * maxOffset * 10) / 10;
      const oy = Math.round((Math.random() * 2 - 1) * maxOffset * 0.6 * 10) / 10;
      setPupilOffset(ox, oy, true);
      const nextDelay = 2500 + Math.random() * 1500; // 2.5–4s
      idleDriftTimer = setTimeout(drift, nextDelay);
    }
    drift();
  }

  function stopIdleDrift() {
    isIdle = false;
    clearTimeout(idleDriftTimer);
    idleDriftTimer = null;
  }

  function resetIdleTimer() {
    clearTimeout(idleTimer);
    if (isIdle) stopIdleDrift();
    idleTimer = setTimeout(startIdleDrift, 3000);
  }

  // mouse tracking
  document.addEventListener('mousemove', (e) => {
    resetIdleTimer();
    const rect = frogIcon.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const dx = (e.clientX - cx) / window.innerWidth;
    const dy = (e.clientY - cy) / window.innerHeight;
    const maxOffset = 3;
    const ox = Math.round(dx * maxOffset * 10) / 10;
    const oy = Math.round(dy * maxOffset * 10) / 10;
    setPupilOffset(ox, oy, false);
  });

  // start idle timer on load
  resetIdleTimer();

  // blink: random interval 4–8s, 150ms duration
  function scheduleBlink() {
    const delay = 4000 + Math.random() * 4000;
    setTimeout(() => {
      frogIcon.classList.add('frog-blink');
      setTimeout(() => {
        frogIcon.classList.remove('frog-blink');
        scheduleBlink();
      }, 150);
    }, delay);
  }
  scheduleBlink();
}
