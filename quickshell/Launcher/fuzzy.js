.pragma library
/*  Fuzzy scoring for the launcher.  score(query, name, generic, keywords, comment) → number (0 = no match).
 *  Subsequence match on the name with bonuses: prefix, word start, consecutive, exact; generic/keywords/comment weigh less.
 */
function matchOne(q, s) {
    if (!q.length) return 1;
    s = s.toLowerCase();
    const idx = s.indexOf(q);
    if (idx === 0) return 100 + (s.length === q.length ? 50 : 0) - Math.min(20, s.length - q.length);
    if (idx > 0) return 70 + (s[idx - 1] === " " || s[idx - 1] === "-" ? 15 : 0) - Math.min(20, idx);
    // subsequence
    let si = 0, score = 0, streak = 0, matched = 0;
    for (let qi = 0; qi < q.length; qi++) {
        const c = q[qi];
        let found = -1;
        for (let k = si; k < s.length; k++) { if (s[k] === c) { found = k; break; } }
        if (found < 0) return 0;
        matched++;
        if (found === si && qi > 0) { streak++; score += 6 + streak * 2; } else { streak = 0; score += 2; }
        if (found === 0 || s[found - 1] === " " || s[found - 1] === "-" || s[found - 1] === "_" || s[found - 1] === ".") score += 8;
        si = found + 1;
    }
    return matched === q.length ? 20 + score - Math.min(15, s.length / 4) : 0;
}

function score(query, name, generic, keywords, comment) {
    const q = (query || "").trim().toLowerCase();
    if (!q.length) return 1;
    const words = q.split(/\s+/);
    let total = 0;
    for (let w = 0; w < words.length; w++) {
        const a = matchOne(words[w], name || "");
        const b = matchOne(words[w], generic || "") * 0.6;
        const c = matchOne(words[w], keywords || "") * 0.5;
        const d = matchOne(words[w], comment || "") * 0.3;
        const best = Math.max(a, b, c, d);
        if (best <= 0) return 0;
        total += best;
    }
    return total;
}
