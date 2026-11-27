// Run in the browser on https://www.parkrun.com.au/willoughby/results/latestresults/
// Says whether today's results are out: 'RESULTS OUT 2026-11-28', 'NO RESULTS YET (latest 2026-11-21)', or an error string.
(() => {
  if (/confirm you are human/i.test(document.title)) return 'ERROR: human check (' + location.href + ')';
  const head = (document.querySelector('.Results-header') || document.body).innerText;
  const m = head.match(/\b(\d{2})\/(\d{2})\/(\d{4})\b/);
  if (!m) return 'ERROR: no results date found on ' + location.href;
  const latest = `${m[3]}-${m[2]}-${m[1]}`;
  const d = new Date();
  const today = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return latest === today ? 'RESULTS OUT ' + latest : 'NO RESULTS YET (latest ' + latest + ')';
})()
