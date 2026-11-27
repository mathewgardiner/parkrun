// Run in the browser on a parkrun profile page (https://www.parkrun.com.au/parkrunner/<number>/).
// Returns the exact text for data/A<number>.txt, or an error string if the page isn't a profile.
(() => {
  const h2 = document.querySelector('h2')?.innerText.trim() || '';
  const id = (h2.match(/\((A\d+)\)/) || [])[1];
  if (!id) return 'ERROR: not a profile page (' + document.title + ')';
  const total = (document.body.innerText.match(/(\d+) parkruns total/) || [])[1];
  const tables = [...document.querySelectorAll('table')];
  const heads = (t) => [...t.querySelectorAll('thead th')].map((th) => th.innerText.trim());
  const summary = tables.find((t) => heads(t).includes('Best Time') && heads(t).some((h) => /^parkruns$/i.test(h)));
  const vol = tables.find((t) => heads(t).includes('Occasions'));
  if (!summary || !total) return 'ERROR: Event Summaries table or total not found for ' + id;
  const cells = (tr) => [...tr.querySelectorAll('td')].map((td) => td.innerText.trim());
  const col = (t, name) => heads(t).indexOf(name);
  const iEv = col(summary, 'Event'), iRuns = heads(summary).findIndex((h) => /^parkruns$/i.test(h)), iBest = col(summary, 'Best Time');
  const rows = [...summary.querySelectorAll('tbody tr')].map(cells)
    .map((c) => `${c[iEv].replace(' parkrun', '')}|${c[iRuns]}|${c[iBest]}`);
  let credits = 0, roles = [];
  if (vol) {
    roles = [...vol.querySelectorAll('tbody tr')].map(cells).map((c) => `${c[0]} ${c[1]}`);
    credits = parseInt((vol.querySelector('tfoot')?.innerText.match(/(\d+)/) || [0, 0])[1], 10);
  }
  const d = new Date();
  const today = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;  // local date
  const first = h2.split(/\s+/)[0];  // first name only: no surnames in the public repo
  // Latest run, from "Most Recent parkruns" (used by refresh-status.ps1 to tell whether this week's result is in)
  const recent = tables.find((t) => heads(t).includes('Run Date'));
  let latest = 'none';
  if (recent) {
    const r = recent.querySelector('tbody tr');
    const c = r ? cells(r) : [];
    const dm = (c[col(recent, 'Run Date')] || '').match(/(\d{2})\/(\d{2})\/(\d{4})/);
    if (dm) latest = `${dm[3]}-${dm[2]}-${dm[1]} ${(c[col(recent, 'Event')] || '').replace(' parkrun', '')}`;
  }
  return [
    `# ${first} (${id}) — fetched ${today} from ${location.href} (Event Summaries)`,
    `# total: ${total}`,
    `# Latest run: ${latest}`,
    `# Volunteer credits: ${credits}`,
    `# Volunteer roles: ${roles.join(', ')}`,
    '# Event|Runs|BestTime',
    ...rows
  ].join('\n') + '\n';
})()
