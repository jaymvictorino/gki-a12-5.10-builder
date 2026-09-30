#!/usr/bin/env python3
# encoding: utf-8
"""
Compare symbols between abi_gki_aarch64.xml and Module.symvers.

Usage:
    python3 KMI_function_symbols_test.py <abi_gki_aarch64.xml> <Module.symvers>

Exit codes:
    0 — OK (either all symbols found, or only informational output)
    1 — File error or parse error
"""

import sys
import argparse
from typing import Set
from pathlib import Path

try:
    from lxml import etree
except ImportError:
    print("ERROR: lxml is required. Install with: pip3 install lxml", file=sys.stderr)
    sys.exit(1)

def setup_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compare symbols between abi_gki_aarch64.xml and Module.symvers."
    )
    parser.add_argument("xml_file", type=str, help="Path to abi_gki_aarch64.xml")
    parser.add_argument("symvers_file", type=str, help="Path to Module.symvers")
    return parser

def read_xml_symbols(xml_file: Path) -> Set[str]:
    with open(xml_file, "r", encoding="utf-8") as f:
        root = etree.parse(f).getroot()
        return {
            el.get("name")
            for el in root.xpath(
                ".//elf-function-symbols/elf-symbol | "
                ".//elf-variable-symbols/elf-symbol"
            )
            if el.get("name")
        }

def read_symvers_symbols(symvers_file: Path) -> Set[str]:
    syms: Set[str] = set()
    with open(symvers_file, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) >= 2:
                syms.add(parts[1])
    return syms

def compare_symbols(xml_file: Path, symvers_file: Path) -> int:
    if not xml_file.is_file():
        print(f"Error: XML file not found: {xml_file}")
        return 1
    if not symvers_file.is_file():
        print(f"Error: Symvers file not found: {symvers_file}")
        return 1

    try:
        abi_symbols = read_xml_symbols(xml_file)
        symvers_symbols = read_symvers_symbols(symvers_file)
    except Exception as e:
        print(f"An error occurred while parsing: {e}")
        return 1

    missing = abi_symbols - symvers_symbols

    if not missing:
        print("\nAll symbols found in Module.symvers.\n")
        return 0

    print("\nMissing symbols from Module.symvers:")
    for s in sorted(missing):
        print(f"- {s}")
    print("")
    return 0

def main() -> int:
    args = setup_arg_parser().parse_args()
    return compare_symbols(Path(args.xml_file), Path(args.symvers_file))

if __name__ == "__main__":
    sys.exit(main())
