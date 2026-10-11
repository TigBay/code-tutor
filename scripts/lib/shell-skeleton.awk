# Reduce a shell command to its "skeleton" so write patterns can be matched
# without false positives from text:
#   - quoted strings ('...' and "...") become the placeholder Q
#   - heredoc bodies are dropped, the "<<DELIM" marker stays
# Everything else is kept as is. Portable POSIX awk (works with mawk).

BEGIN { q = ""; hd = ""; pend = "" }

{
  line = $0

  # inside a heredoc body: skip lines up to and including the delimiter
  if (hd != "") {
    t = line
    if (hdstrip) sub(/^\t+/, "", t)
    if (t == hd) hd = ""
    next
  }

  out = ""
  n = length(line)
  for (i = 1; i <= n; i++) {
    c = substr(line, i, 1)

    if (q == "'") {
      if (c == "'") { q = ""; out = out "Q" }
      continue
    }
    if (q == "\"") {
      if (c == "\\") { i++; continue }
      if (c == "\"") { q = ""; out = out "Q" }
      continue
    }

    if (c == "\\") { out = out substr(line, i, 2); i++; continue }
    if (c == "'" || c == "\"") { q = c; continue }

    # heredoc start "<<DELIM" or "<<-DELIM", but not the here-string "<<<"
    if (c == "<" && substr(line, i, 2) == "<<" && substr(line, i + 2, 1) != "<" && (i == 1 || substr(line, i - 1, 1) != "<")) {
      rest = substr(line, i + 2)
      strip = 0
      if (substr(rest, 1, 1) == "-") { strip = 1; rest = substr(rest, 2) }
      if (match(rest, /^[ \t]*['"]?[A-Za-z_][A-Za-z0-9_]*['"]?/)) {
        d = substr(rest, RSTART, RLENGTH)
        gsub(/[ \t'"]/, "", d)
        pend = d
        pendstrip = strip
        out = out "<<" d
        i += 1 + strip + RLENGTH
        continue
      }
    }

    out = out c
  }
  print out

  if (pend != "") { hd = pend; hdstrip = pendstrip; pend = "" }
}
