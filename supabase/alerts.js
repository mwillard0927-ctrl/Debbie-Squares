// Debbie's Squares alerts — loaded by the Supabase function squares-alerts
let sb;
export function start(webpush, createClient) {
sb = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
WP = webpush;
WP.setVapidDetails("mailto:alerts@example.com", Deno.env.get("VAPID_PUBLIC_KEY"), Deno.env.get("VAPID_PRIVATE_KEY"));
Deno.serve(handler);
}
let WP;
const DT = {CBS:"WWJ CBS 62",FOX:"WJBK FOX 2",NBC:"WDIV NBC 4",ABC:"WXYZ ABC 7"};
const MT = {DET:["DET"],PHX:["ARI"],ATL:["ATL"],BAL:["BAL"],BUF:["BUF"],CLT:["CAR"],CHI:["CHI"],CIN:["CIN"],CLE:["CLE"],DAL:["DAL"],DEN:["DEN"],GB:["GB"],MIL:["GB"],HOU:["HOU"],IND:["IND"],JAX:["JAX"],KC:["KC"],LV:["LV"],LA:["LAR","LAC"],MIA:["MIA"],MIN:["MIN"],BOS:["NE"],NO:["NO"],NY:["NYG","NYJ"],PHI:["PHI"],PIT:["PIT"],SF:["SF"],SEA:["SEA"],TB:["TB"],NSH:["TEN"],DC:["WSH"]};
function how(g, t, P) {
  const v = g.tvs.join(" ").toUpperCase(), has = (k) => v.includes(k);
  if (!P || !P.mkt) return g.tvs[0] || "channel TBA";
  const H = P.have || {}, loc = H.ant || H.cable || H.live, mk = MT[P.mkt] || [];
  const ch = (k) => P.mkt == "DET" ? DT[k] : "your local " + k + " station";
  const home = mk.includes(t) || mk.includes(g.opp);
  const d = new Date(new Date(g.date).toLocaleString("en-US", {timeZone: "America/New_York"}));
  const regional = d.getDay() == 0 && d.getHours() < 20 && !home;
  for (const k of ["NBC","ABC","CBS","FOX"]) {
    if (!has(k)) continue;
    if ((k == "CBS" || k == "FOX") && regional) return H.st ? "NFL Sunday Ticket" : k + " (regional, may not be shown in your area)";
    if (loc) return ch(k) + (H.ant ? " (free with antenna)" : "");
    if (k == "CBS" && H.paramount) return "Paramount+";
    if (k == "NBC" && H.peacock) return "Peacock";
    return k + " (you may not have this)";
  }
  if (has("PRIME")) return H.prime ? "Prime Video" : (home && loc ? "your local station" : "Prime Video (you may not have this)");
  if (has("NETFLIX")) return H.netflix ? "Netflix" : "Netflix (you may not have this)";
  if (has("PEACOCK")) return H.peacock ? "Peacock" : "Peacock (you may not have this)";
  if (has("ESPN")) return (H.cable || H.live || H.espn) ? "ESPN" : (H.nflplus ? "NFL+ app" : "ESPN (you may not have this)");
  if (has("NFL NET")) return (H.cable || H.live) ? "NFL Network" : (H.nflplus ? "NFL+ app" : "NFL Network (you may not have this)");
  if (has("YOUTUBE")) return "YouTube (free)";
  return g.tvs[0] || "channel TBA";
}
const when = (d) => new Date(d).toLocaleString("en-US", {timeZone: "America/New_York", weekday: "short", hour: "numeric", minute: "2-digit"});
function parse(j) {
  const G = {};
  for (const ev of j.events || []) {
    const c = ev.competitions[0];
    const tvs = (c.broadcasts || []).flatMap((b) => b.names || []);
    for (const cp of c.competitors) {
      const op = c.competitors.find((o) => o != cp);
      const fix = (a) => a == "WAS" ? "WSH" : a;
      G[fix(cp.team.abbreviation)] = { name: cp.team.shortDisplayName, state: c.status.type.state, score: +cp.score || 0,
        detail: c.status.type.shortDetail, home: cp.homeAway == "home", date: ev.date, tvs,
        opp: fix(op.team.abbreviation), oppName: op.team.shortDisplayName, oppScore: +op.score || 0 };
    }
  }
  return G;
}
const SB = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard";
const WK = {};
async function getWeek(n) { if (!WK[n]) WK[n] = parse(await (await fetch(SB + "?seasontype=2&dates=2026&week=" + n)).json()); return WK[n]; }
async function teamPts(t, week, GG) {
  if (GG[t]) return GG[t].score;
  for (let j = week - 1; j >= 1; j--) { const P = await getWeek(j); if (P[t]) return P[t].score; }
  return 0;
}
async function push(s, m) {
  try { await WP.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(m), { TTL: 3600 }); return 1; }
  catch (e) { if (e.statusCode == 404 || e.statusCode == 410) { await sb.from("squares_push_subs").delete().eq("endpoint", s.endpoint); return -1; } return 0; }
}
function handler() { return (async () => {
  const j = await (await fetch(SB)).json();
  if (!j.season || j.season.type != 2) return new Response("off");
  const wk = j.week.number, G = parse(j); WK[wk] = G;
  const { data: prev } = await sb.from("squares_game_state").select("*").like("key", wk + "-%");
  const old = {}; for (const p of prev || []) old[p.key] = p;
  const E = {}, ups = [];
  for (const t in G) {
    const g = G[t], key = wk + "-" + t, p = old[key];
    ups.push({ key, state: g.state, score: g.score });
    if (!p) continue;
    const e = (E[t] = []);
    if (p.state == "pre" && g.state == "in") e.push({ type: "k", key });
    else if (g.state != "pre" && g.score > p.score) e.push({ type: "s", key, plus: g.score - p.score });
    if (p.state != "post" && g.state == "post") e.push({ type: "f", key });
  }
  if (ups.length) await sb.from("squares_game_state").upsert(ups);
  const { data: hu } = await sb.from("squares_game_state").select("key").eq("key", "hu-" + wk);
  const sendHU = !(hu && hu.length) && ups.length > 0;
  // results: winning high/low just entered by the admin
  const R = [];
  const { data: wr } = await sb.from("squares_pool_weekly").select("*").eq("pool", "DEBBIE");
  for (const r of wr || []) {
    if (r.high == null || r.low == null) continue;
    const sig = r.high + "-" + r.low, key = "res-" + r.week;
    const { data: st } = await sb.from("squares_game_state").select("state").eq("key", key);
    if (st && st.length && st[0].state == sig) continue;
    await sb.from("squares_game_state").upsert({ key, state: sig });
    if (Date.now() - new Date(r.updated_at).getTime() > 20 * 60000) continue;
    const GW = await getWeek(r.week);
    R.push({ week: r.week, high: r.high, low: r.low, G: GW });
  }
  const MB = {};
  const { data: mems } = await sb.from("squares_members").select("name,teams,updated_at").eq("pool", "DEBBIE");
  for (const m of mems || []) if (!MB[m.name] || m.updated_at > MB[m.name].updated_at) MB[m.name] = m;
  const wtot = async (GG, teams, week) => { let x = 0; for (const t of teams || []) x += await teamPts(t, week, GG); return x; };
  const { data: subs } = await sb.from("squares_push_subs").select("*");
  let sent = 0;
  for (const s of subs || []) {
    const mine = (s.teams && s.teams[wk - 1]) || [], out = [];
    for (const t of mine) for (const e of (E[t] || [])) {
      const g = G[t], vs = (g.home ? "vs " : "at ") + g.oppName;
      if (e.type == "k") out.push({ title: "Kickoff: " + g.name + " " + vs, body: "Week " + wk + " - Watch: " + how(g, t, s.tv), tag: "k" + e.key });
      if (e.type == "s") out.push({ title: g.name + " scored! +" + e.plus, body: g.name + " " + g.score + ", " + g.oppName + " " + g.oppScore + " - " + g.detail, tag: "s" + e.key });
      if (e.type == "f") out.push({ title: "Final: " + g.name + " " + g.score, body: g.oppName + " " + g.oppScore + " - Week " + wk, tag: "f" + e.key });
    }
    if (sendHU && mine.length) {
      const lines = mine.map((t) => G[t] ? G[t].name + (G[t].home ? " vs " : " at ") + G[t].oppName + " - " + when(G[t].date) + ", " + how(G[t], t, s.tv) : t + ": BYE");
      out.push({ title: "Week " + wk + " heads-up", body: lines.join("\n"), tag: "hu" });
    }
    for (const r of R) {
      const teams = (s.teams && s.teams[r.week - 1]) || [];
      const tot = await wtot(r.G, teams, r.week);
      let msg = "You had " + tot + ". ";
      if (tot >= r.high) msg = "You won the high with " + tot + "!";
      else if (tot <= r.low) msg = "You won the low with " + tot + "!";
      else msg += (tot - r.low <= r.high - tot) ? (tot - r.low) + " from the low." : (r.high - tot) + " from the high.";
      out.push({ title: "Week " + r.week + " results: High " + r.high + ", Low " + r.low, body: teams.length ? msg : "Winning numbers are in.", tag: "r" + r.week });
    }
    for (const f of (Array.isArray(s.favs) ? s.favs : [])) {
      if (f == s.name || !MB[f]) continue;
      const ft = (MB[f].teams && MB[f].teams[wk - 1]) || [];
      for (const t of ft) for (const e of (E[t] || [])) if (e.type == "s")
        out.push({ title: "\u2B50 " + f + ": " + G[t].name + " scored +" + e.plus, body: f + "'s Week " + wk + " total: " + (await wtot(G, ft, wk)), tag: "fs" + f + e.key });
      for (const r of R) {
        const tot = await wtot(r.G, (MB[f].teams && MB[f].teams[r.week - 1]) || [], r.week);
        if (tot >= r.high) out.push({ title: "\u2B50 " + f + " won the Week " + r.week + " high!", body: f + " had " + tot + " (high was " + r.high + ")", tag: "fw" + f + r.week });
        else if (tot <= r.low) out.push({ title: "\u2B50 " + f + " won the Week " + r.week + " low!", body: f + " had " + tot + " (low was " + r.low + ")", tag: "fw" + f + r.week });
      }
    }
    for (const m of out) { const k = await push(s, m); if (k < 0) break; sent += k; }
  }
  if (sendHU) await sb.from("squares_game_state").upsert({ key: "hu-" + wk, state: "sent" });
  return new Response("sent " + sent);
})(); }
