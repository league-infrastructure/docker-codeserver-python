#!/usr/bin/env python3
"""
Update Jupyter notebooks in the current directory (recursively)
to use a specified kernelspec name.

Usage:
    python update_kernelspec.py codehost
"""

import argparse
import json
import pathlib
import time

def main():
    parser = argparse.ArgumentParser(
        description="Update kernelspec name in all Jupyter notebooks."
    )
    parser.add_argument("kernelspec", help="Name of the kernelspec (e.g. codehost)")
    args = parser.parse_args()

    root = pathlib.Path(".")
    stamp = time.strftime("%Y%m%d-%H%M%S")
    updated = 0

    for p in root.rglob("*.ipynb"):
        if ".ipynb_checkpoints" in p.parts:
            continue

        try:
            text = p.read_text(encoding="utf-8")
            nb = json.loads(text)
        except Exception as e:
            print(f"[skip] {p} (error reading JSON: {e})")
            continue

        meta = nb.setdefault("metadata", {})
        ks = meta.setdefault("kernelspec", {})

        before = dict(ks)
        ks["name"] = args.kernelspec
        ks.setdefault("display_name", args.kernelspec)
        ks.setdefault("language", meta.get("language_info", {}).get("name", "python"))

        if ks != before:
            backup = p.with_suffix(p.suffix + f".bak.{stamp}")
            backup.write_text(text, encoding="utf-8", errors="ignore")
            p.write_text(
                json.dumps(nb, ensure_ascii=False, indent=1) + "\n",
                encoding="utf-8",
            )
            print(f"[updated] {p}  ← {before.get('name')} → {args.kernelspec}")
            updated += 1
        else:
            print(f"[ok] {p} already set")

    print(f"\nDone. {updated} notebook(s) updated. Backups: *.bak.{stamp}")

if __name__ == "__main__":
    main()