#!/usr/bin/env python3
"""SQLite fixture for exact Accounts3 authorization semantics.

This does not execute Objective-C. It locks the SQL/data invariants used by
AppDataCleaner: exact ZOWNINGBUNDLEID matching, target-PK companion deletion,
unrelated-account preservation, no global orphan sweep, and rollback safety.
"""
import sqlite3

TARGET = "com.example.target"


def make_db(*, with_owner: bool = True) -> sqlite3.Connection:
    db = sqlite3.connect(":memory:")
    owner_col = ", ZOWNINGBUNDLEID TEXT" if with_owner else ""
    db.executescript(
        f"""
        CREATE TABLE ZACCOUNT (Z_PK INTEGER PRIMARY KEY{owner_col}, ZUSERNAME TEXT);
        CREATE TABLE ZACCOUNTPROPERTY (Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER, ZKEY TEXT);
        CREATE TABLE ZCREDENTIALITEM (Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER, ZLABEL TEXT);
        """
    )
    if with_owner:
        db.executemany(
            "INSERT INTO ZACCOUNT(Z_PK,ZOWNINGBUNDLEID,ZUSERNAME) VALUES(?,?,?)",
            [
                (1, TARGET, "target-a"),
                (2, "com.google.accounts", "gmail-user"),
                (3, "com.apple.accountsd", "icloud-user"),
                (4, TARGET, "target-b"),
                (5, TARGET + ".beta", "substring-must-survive"),
                (6, "com.microsoft.exchange", "exchange-user"),
                (7, None, "unowned-user"),
            ],
        )
    else:
        db.execute("INSERT INTO ZACCOUNT(Z_PK,ZUSERNAME) VALUES(1,'target-a')")
    db.executemany(
        "INSERT INTO ZACCOUNTPROPERTY(Z_PK,ZOWNER,ZKEY) VALUES(?,?,?)",
        [(10, 1, "target"), (20, 2, "gmail"), (30, 3, "icloud"),
         (40, 4, "target"), (50, 5, "substring"), (99, 999, "preexisting-orphan")],
    )
    db.executemany(
        "INSERT INTO ZCREDENTIALITEM(Z_PK,ZOWNER,ZLABEL) VALUES(?,?,?)",
        [(110, 1, "target"), (120, 2, "gmail"), (130, 3, "icloud"),
         (140, 4, "target"), (150, 5, "substring"), (199, 999, "preexisting-orphan")],
    )
    db.commit()
    return db


def has_exact_schema(db: sqlite3.Connection) -> bool:
    cols = {row[1] for row in db.execute("PRAGMA table_info('ZACCOUNT')")}
    return {"Z_PK", "ZOWNINGBUNDLEID"}.issubset(cols)


def exact_targets(db: sqlite3.Connection) -> list[int]:
    return [row[0] for row in db.execute(
        "SELECT Z_PK FROM ZACCOUNT WHERE ZOWNINGBUNDLEID = ? ORDER BY Z_PK", (TARGET,)
    )]


def unrelated(db: sqlite3.Connection) -> list[int]:
    return [row[0] for row in db.execute(
        "SELECT Z_PK FROM ZACCOUNT "
        "WHERE ZOWNINGBUNDLEID IS NULL OR ZOWNINGBUNDLEID <> ? ORDER BY Z_PK", (TARGET,)
    )]


def mutate_exact(db: sqlite3.Connection, *, fail_after_first: bool = False) -> bool:
    if not has_exact_schema(db):
        return False
    planned = exact_targets(db)
    if not planned:
        return True
    unrelated_before = unrelated(db)
    try:
        db.execute("BEGIN IMMEDIATE")
        if exact_targets(db) != planned:
            raise RuntimeError("target ownership changed")
        for index, pk in enumerate(planned):
            db.execute("DELETE FROM ZACCOUNTPROPERTY WHERE ZOWNER = ?", (pk,))
            db.execute("DELETE FROM ZCREDENTIALITEM WHERE ZOWNER = ?", (pk,))
            cur = db.execute(
                "DELETE FROM ZACCOUNT WHERE Z_PK = ? AND ZOWNINGBUNDLEID = ?", (pk, TARGET)
            )
            if cur.rowcount != 1:
                raise RuntimeError("exact account delete mismatch")
            if fail_after_first and index == 0:
                raise RuntimeError("injected failure")
        if exact_targets(db):
            raise RuntimeError("target rows remain")
        if unrelated(db) != unrelated_before:
            raise RuntimeError("unrelated PK set changed")
        db.commit()
        return True
    except Exception:
        db.rollback()
        return False


def rows(db: sqlite3.Connection, table: str) -> set[tuple]:
    return set(db.execute(f"SELECT * FROM {table}"))


def main() -> None:
    db = make_db()
    before_accounts = rows(db, "ZACCOUNT")
    assert exact_targets(db) == [1, 4]
    assert unrelated(db) == [2, 3, 5, 6, 7]
    assert mutate_exact(db)
    assert {r[0] for r in rows(db, "ZACCOUNT")} == {2, 3, 5, 6, 7}
    assert {r[1] for r in rows(db, "ZACCOUNTPROPERTY")} == {2, 3, 5, 999}
    assert {r[1] for r in rows(db, "ZCREDENTIALITEM")} == {2, 3, 5, 999}
    # Exact equality: a bundle that merely contains TARGET survives.
    assert any(r[0] == 5 and r[1] == TARGET + ".beta" for r in rows(db, "ZACCOUNT"))
    # Pre-existing unrelated orphans survive; there is no global orphan sweep.
    assert any(r[1] == 999 for r in rows(db, "ZACCOUNTPROPERTY"))
    assert any(r[1] == 999 for r in rows(db, "ZCREDENTIALITEM"))

    rollback_db = make_db()
    rollback_snapshot = {
        table: rows(rollback_db, table)
        for table in ("ZACCOUNT", "ZACCOUNTPROPERTY", "ZCREDENTIALITEM")
    }
    assert not mutate_exact(rollback_db, fail_after_first=True)
    for table, expected in rollback_snapshot.items():
        assert rows(rollback_db, table) == expected, f"rollback changed {table}"

    unsupported = make_db(with_owner=False)
    unsupported_before = rows(unsupported, "ZACCOUNT")
    assert not has_exact_schema(unsupported)
    assert not mutate_exact(unsupported)
    assert rows(unsupported, "ZACCOUNT") == unsupported_before

    # Ensure the fixture itself actually contained unrelated account classes.
    assert any(r[0] == 2 for r in before_accounts)
    assert any(r[0] == 3 for r in before_accounts)
    assert any(r[0] == 6 for r in before_accounts)
    print("Exact Accounts3 authorization SQLite fixture: PASS")


if __name__ == "__main__":
    main()
