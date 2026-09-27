#!/usr/bin/env bash
# Redact a resume's front matter (the block between the opening and closing
# "---"): remove email and phone number. Links are kept. The body is untouched.
#
# Usage: ./redact.sh [input.md] [output.md]
# Defaults: resume.md -> redacted_resume.md
set -euo pipefail

in="${1:-resume.md}"
out="${2:-redacted_resume.md}"

if [[ ! -f "$in" ]]; then
  echo "error: $in not found" >&2
  exit 1
fi

awk '
  function is_email(s) { return s ~ /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}/ }
  function is_phone(s) { return s ~ /[+]?[0-9][0-9 ().-]{6,}[0-9]/ }

  # Scrub a single front matter line (safety net for anything embedded in text)
  function redact_line(s) {
    gsub(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}/, "", s)
    gsub(/[+]?[0-9][0-9 ().-]{6,}[0-9]/, "", s)
    return s
  }

  # Flush the buffered header entry: drop it if it has an email/phone,
  # otherwise print it as-is (links included)
  function flush_item(   n, i, ls) {
    if (!in_item) return
    if (is_email(buf) || is_phone(buf)) {
      dropped++
    } else {
      n = split(buf, ls, "\n")
      for (i = 1; i <= n; i++) print redact_line(ls[i])
    }
    buf = ""
    in_item = 0
  }

  BEGIN { in_fm = 0; in_header = 0; in_item = 0; dropped = 0 }

  NR == 1 && $0 == "---" { in_fm = 1; print; next }

  # Closing front matter delimiter: from here on, output is verbatim
  in_fm && $0 == "---" {
    flush_item()
    in_fm = 0
    print
    next
  }

  # Body: never touched
  !in_fm { print; next }

  # Front matter
  {
    if ($0 ~ /^header:[ \t]*$/) { flush_item(); in_header = 1; print; next }
    if (in_header && $0 ~ /^[^ ]/) { flush_item(); in_header = 0 }   # new top-level key

    if (in_header && $0 ~ /^  - /) { flush_item(); buf = $0; in_item = 1; next }
    if (in_item) { buf = buf "\n" $0; next }

    print redact_line($0)
    next
  }

  END {
    if (dropped)
      printf("removed %d front matter entries containing email/phone\n", dropped) > "/dev/stderr"
  }
' "$in" > "$out"

echo "$in -> $out"
