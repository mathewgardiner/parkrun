// Run in the browser on a parkrun event page (https://www.parkrun.com.au/<slug>/).
// Returns the Saturday start time, e.g. '7:00am', for scripts/set-start-time.ps1, or an error string.
(() => {
  if (/confirm you are human/i.test(document.title)) return 'ERROR: human check (' + location.href + ')';
  const text = document.body.innerText;
  const m = text.match(/Saturday[^\n.]{0,40}?\b(\d{1,2})[:.](\d{2})\s*([ap])\.?m/i)
    || text.match(/\b(\d{1,2})[:.](\d{2})\s*([ap])\.?m\b[^\n.]{0,40}Saturday/i);
  if (!m) return 'ERROR: no Saturday start time found on ' + location.href;
  return `${parseInt(m[1], 10)}:${m[2]}${m[3].toLowerCase()}m`;
})()
