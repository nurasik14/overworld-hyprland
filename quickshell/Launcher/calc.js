.pragma library
/*  Safe arithmetic evaluator: numbers (decimals), + - * / % ^, parentheses, unary minus, and a few functions
 *  (sqrt, abs, round, floor, ceil, sin, cos, tan, log, ln, exp) and constants (pi, e).  No eval, no identifiers beyond these.
 *  evaluate("2*(3+4.5)") → { ok: true, value: 15 } | { ok: false, error: "…" }
 */
function tokenize(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
        const ch = s[i];
        if (ch === " " || ch === "\t" || ch === ",") { i++; continue; }
        if ((ch >= "0" && ch <= "9") || ch === ".") {
            let j = i; let dot = false;
            while (j < s.length && ((s[j] >= "0" && s[j] <= "9") || (s[j] === "." && !dot))) { if (s[j] === ".") dot = true; j++; }
            const num = parseFloat(s.substring(i, j));
            if (isNaN(num)) return { error: "bad number" };
            out.push({ t: "n", v: num }); i = j; continue;
        }
        if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z")) {
            let j = i;
            while (j < s.length && /[a-zA-Z]/.test(s[j])) j++;
            out.push({ t: "id", v: s.substring(i, j).toLowerCase() }); i = j; continue;
        }
        if ("+-*/%^()×÷".indexOf(ch) >= 0) {
            out.push({ t: "op", v: ch === "×" ? "*" : (ch === "÷" ? "/" : ch) }); i++; continue;
        }
        return { error: "unexpected '" + ch + "'" };
    }
    return { tokens: out };
}

const FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, log: Math.log10, ln: Math.log, exp: Math.exp
};
const CONSTS = { pi: Math.PI, e: Math.E };

function Parser(tokens) { this.toks = tokens; this.pos = 0; }
Parser.prototype.peek = function() { return this.toks[this.pos]; };
Parser.prototype.next = function() { return this.toks[this.pos++]; };
Parser.prototype.expr = function() {           // additive
    let v = this.term();
    while (this.peek() && this.peek().t === "op" && (this.peek().v === "+" || this.peek().v === "-")) {
        const op = this.next().v; const r = this.term();
        v = op === "+" ? v + r : v - r;
    }
    return v;
};
Parser.prototype.term = function() {           // multiplicative
    let v = this.power();
    while (this.peek() && this.peek().t === "op" && (this.peek().v === "*" || this.peek().v === "/" || this.peek().v === "%")) {
        const op = this.next().v; const r = this.power();
        if (op === "*") v = v * r;
        else if (op === "/") { if (r === 0) throw new Error("division by zero"); v = v / r; }
        else v = v % r;
    }
    return v;
};
Parser.prototype.power = function() {
    const base = this.unary();
    if (this.peek() && this.peek().t === "op" && this.peek().v === "^") { this.next(); return Math.pow(base, this.power()); }
    return base;
};
Parser.prototype.unary = function() {
    const t = this.peek();
    if (t && t.t === "op" && t.v === "-") { this.next(); return -this.unary(); }
    if (t && t.t === "op" && t.v === "+") { this.next(); return this.unary(); }
    return this.primary();
};
Parser.prototype.primary = function() {
    const t = this.next();
    if (!t) throw new Error("unexpected end");
    if (t.t === "n") return t.v;
    if (t.t === "id") {
        if (CONSTS[t.v] !== undefined) return CONSTS[t.v];
        if (FUNCS[t.v]) {
            const p = this.peek();
            if (!p || p.t !== "op" || p.v !== "(") throw new Error(t.v + " needs (…)");
            this.next();
            const arg = this.expr();
            const c = this.next();
            if (!c || c.v !== ")") throw new Error("missing )");
            return FUNCS[t.v](arg);
        }
        throw new Error("unknown '" + t.v + "'");
    }
    if (t.t === "op" && t.v === "(") {
        const v = this.expr();
        const c = this.next();
        if (!c || c.v !== ")") throw new Error("missing )");
        return v;
    }
    throw new Error("unexpected '" + t.v + "'");
};

function evaluate(src) {
    const tk = tokenize(src || "");
    if (tk.error) return { ok: false, error: tk.error };
    if (!tk.tokens.length) return { ok: false, error: "" };
    try {
        const p = new Parser(tk.tokens);
        const v = p.expr();
        if (p.pos !== tk.tokens.length) return { ok: false, error: "unexpected '" + tk.tokens[p.pos].v + "'" };
        if (typeof v !== "number" || !isFinite(v)) return { ok: false, error: "not a number" };
        return { ok: true, value: v };
    } catch (e) {
        return { ok: false, error: e.message };
    }
}

function format(v) {
    if (Math.abs(v - Math.round(v)) < 1e-12) return String(Math.round(v));
    return String(parseFloat(v.toPrecision(12)));
}
