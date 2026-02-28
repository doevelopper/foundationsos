#!/usr/bin/env python3
"""Validate Buildroot defconfig syntax.

Ensures every non-comment, non-blank line follows one of:
  - BR2_OPTION=y
  - BR2_OPTION=n
  - BR2_OPTION="value"
  - BR2_OPTION=value
  - # BR2_OPTION is not set
"""
import re
import sys

VALID_LINE = re.compile(
    r'^[A-Za-z][A-Za-z0-9_]+=.*$'
)
NOT_SET = re.compile(
    r'^# [A-Za-z][A-Za-z0-9_]+ is not set$'
)


def check_defconfig(path: str) -> int:
    errors = 0
    with open(path) as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.rstrip('\n')
            if not line or line.startswith('#'):
                if line.startswith('# ') and 'is not set' in line:
                    if not NOT_SET.match(line):
                        print(f"{path}:{lineno}: malformed 'is not set': {line}")
                        errors += 1
                continue
            if not VALID_LINE.match(line):
                print(f"{path}:{lineno}: invalid syntax: {line}")
                errors += 1
    return errors


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <defconfig>", file=sys.stderr)
        sys.exit(1)
    n = check_defconfig(sys.argv[1])
    if n:
        print(f"{n} error(s) found in {sys.argv[1]}")
        sys.exit(1)
    print(f"{sys.argv[1]}: syntax OK")
