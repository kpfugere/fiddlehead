// terminal typewriter animation
const container = document.getElementById('terminal-lines');
const output = document.getElementById('terminal-output');

if (container) {
  const lines = [
    { text: '$ fiddlehead', class: '', delay: 600 },
    { text: '○ ready — press cmd+shift+r to start', class: '', delay: 1200 },
    { text: '◎ listening 0:00', class: 'term-listening', delay: 400 },
    { text: '◎ listening 0:08', class: 'term-listening', delay: 400 },
    { text: '◎ listening 0:15', class: 'term-listening', delay: 400 },
    { text: '◎ listening 0:23', class: 'term-listening', delay: 800 },
    { text: '◎ transcribing...', class: 'term-processing', delay: 1500 },
    { text: '◎ structuring...', class: 'term-processing', delay: 1200 },
    { text: '✓ saved → 2026-02-10_standup-sync.md', class: 'term-saved', delay: 0 },
  ];

  let started = false;

  const observer = new IntersectionObserver(
    ([entry]) => {
      if (entry.isIntersecting && !started) {
        started = true;
        observer.disconnect();
        runAnimation();
      }
    },
    { threshold: 0.5 }
  );
  observer.observe(container.closest('.terminal-wrapper') || container);

  async function runAnimation() {
    for (const line of lines) {
      await addLine(line);
    }
    // show output preview
    if (output) {
      await sleep(500);
      output.style.display = 'block';
    }
  }

  function addLine({ text, class: cls, delay }) {
    return new Promise((resolve) => {
      const el = document.createElement('div');
      el.className = 'term-line' + (cls ? ' ' + cls : '');

      // listening lines replace each other
      if (cls === 'term-listening') {
        const prev = container.querySelector('.term-listening');
        if (prev) prev.remove();
      }

      container.appendChild(el);
      typeText(el, text, () => {
        setTimeout(resolve, delay);
      });
    });
  }

  function typeText(el, text, onDone) {
    let i = 0;
    const cursor = document.createElement('span');
    cursor.className = 'terminal-cursor';
    el.appendChild(cursor);

    const interval = setInterval(() => {
      if (i < text.length) {
        el.insertBefore(document.createTextNode(text[i]), cursor);
        i++;
      } else {
        clearInterval(interval);
        cursor.remove();
        onDone();
      }
    }, 35);
  }

  function sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
  }
}
