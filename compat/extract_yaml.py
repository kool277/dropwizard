#!/usr/bin/env python3
"""Writes each YAML code block of a reStructuredText file to its own file."""
import pathlib
import sys
import textwrap


def main(rst_path, output_dir):
    lines = pathlib.Path(rst_path).read_text(encoding="utf-8").splitlines()
    stem = pathlib.Path(rst_path).stem
    count, i = 0, 0
    while i < len(lines):
        if lines[i].strip() != ".. code-block:: yaml":
            i += 1
            continue
        i += 1
        block = []
        while i < len(lines) and (not lines[i].strip() or lines[i].startswith(" ")):
            block.append(lines[i])
            i += 1
        text = textwrap.dedent("\n".join(block)).strip()
        if text:
            count += 1
            pathlib.Path(output_dir, f"{stem}-{count:03d}.yml").write_text(text + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
