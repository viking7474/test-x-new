import sqlite3, io
db = r"C:\Users\VanVan\Documents\github\test-x\layout\Library\IOS.db"
out = io.StringIO()
def p(*a):
    out.write(" ".join(str(x) for x in a) + "\n")
con = sqlite3.connect(db)
con.text_factory = lambda b: b.decode('utf-8', 'replace')
cur = con.cursor()

tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
p("=== TABLE COUNTS ===")
for t in tables:
    try:
        n = cur.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
    except Exception as e:
        p(t, "count error", e); continue
    p(f"{t}: {n} rows")

def dump(t, where="", params=(), limit=None):
    cols = [d[1] for d in cur.execute(f'PRAGMA table_info("{t}")')]
    p(f"\n#### {t} cols={cols}")
    q = f'SELECT * FROM "{t}" {where}'
    if limit: q += f' LIMIT {limit}'
    for row in cur.execute(q, params):
        p("  ", dict(zip(cols, row)))

p("\n\n===== CPU (all) =====")
dump("CPU")
p("\n\n===== KMOS (all) =====")
dump("KMOS")
p("\n\n===== KMOperatingSystem (all) =====")
dump("KMOperatingSystem")
p("\n\n===== KMDevices where identifier LIKE iPhone =====")
dump("KMDevices", "WHERE identifier LIKE 'iPhone%' ORDER BY identifier")
p("\n\n===== KMDevSpecial where mod=iPhone10,3 =====")
dump("KMDevSpecial", "WHERE mod = ?", ("iPhone10,3",))

p("\n\n===== SEARCH keywords across all tables =====")
for t in tables:
    cols = [d[1] for d in cur.execute(f'PRAGMA table_info("{t}")')]
    for kw in ("iPhone10,3", "19E258", "D221AP", "iPhone X", "15.4.1", "13.7"):
        for c in cols:
            try:
                rows = cur.execute(f'SELECT * FROM "{t}" WHERE "{c}" LIKE ? LIMIT 3', (f"%{kw}%",)).fetchall()
            except Exception:
                continue
            if rows:
                p(f"[{t}.{c}] ~ '{kw}':")
                for r in rows:
                    p("   ", dict(zip(cols, r)))

with open(r"C:\Users\VanVan\Documents\github\test-x\scripts\iosdb_dump.txt", "w", encoding="utf-8") as f:
    f.write(out.getvalue())
print("OK wrote scripts/iosdb_dump.txt bytes=", len(out.getvalue()))
