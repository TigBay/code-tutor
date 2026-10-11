#!/usr/bin/env bats
#
# Table tests for lib/bash-guard.sh. Each helper call checks a list of
# commands and names the first one that is classified wrongly.

load test_helper

setup() {
  setup_env
  source "$REPO_ROOT/scripts/lib/common.sh"
  source "$REPO_ROOT/scripts/lib/bash-guard.sh"
  P="$CLAUDE_PROJECT_DIR"
}

# expect_write <command...>: every command must be detected as a write.
expect_write() {
  local cmd
  for cmd in "$@"; do
    if ! ct_bash_write_reason "$P" "$cmd" >/dev/null; then
      echo "not detected as write: $cmd" >&2
      return 1
    fi
  done
}

# expect_allowed <command...>: no command may be detected as a write.
expect_allowed() {
  local cmd reason
  for cmd in "$@"; do
    if reason="$(ct_bash_write_reason "$P" "$cmd")"; then
      echo "wrongly detected as write ($reason): $cmd" >&2
      return 1
    fi
  done
}

# --- redirections --------------------------------------------------------------

@test "output redirection into project files is a write" {
  expect_write \
    'echo x > src/Foo.php' \
    'echo x >src/Foo.php' \
    'echo x >> notes.txt' \
    'printf "%s" a 1> out.log' \
    'cmd &> build.log' \
    'cmd &>> build.log' \
    'echo x >| forced.txt' \
    "echo x > \"$P/src/Foo.php\"" \
    "cat > $P/src/Foo.php <<'EOF'
<?php
EOF" \
    'cat <<EOF > config.yaml
key: value
EOF'
}

@test "redirection to devices, file descriptors or outside the project is allowed" {
  expect_allowed \
    'composer test 2>&1' \
    'cmd > /dev/null 2>&1' \
    'cmd 2>/dev/null' \
    'echo error >&2' \
    'cmd &>/dev/null' \
    'echo x > /tmp/scratch.txt' \
    'echo x > ~/notes.txt'
}

@test "angle brackets inside quotes or heredoc bodies are not redirections" {
  expect_allowed \
    'git commit -m "fix: total > 0 check"' \
    "grep -rn '=>' src/" \
    "php -r 'echo 1 > 0;'" \
    'git log --format="%h > %s"' \
    "git commit -F - <<'EOF'
feat: compare a > b
EOF" \
    'python3 - <<EOF
print(1 > 0)
EOF' \
    'grep -c x <<< "a > b"' \
    'echo $(( 1 << 2 ))'
}

@test "arrows and comparisons outside quotes are not redirections" {
  expect_allowed \
    'echo a->b' \
    'echo a=>b'
}

# --- file commands -------------------------------------------------------------

@test "file changing commands inside the project are writes" {
  expect_write \
    'rm src/Foo.php' \
    'rm -rf var/cache' \
    'mv a.php b.php' \
    'touch src/New.php' \
    'truncate -s 0 app.log' \
    'cp /tmp/solution.php src/Foo.php' \
    'ln -s ../shared src/shared' \
    'rsync -a /tmp/x/ src/' \
    'patch -p1 < fix.diff' \
    'tee src/Foo.php < /tmp/x' \
    'cat x | tee -a notes.md' \
    'dd if=/dev/zero of=blob.bin bs=1 count=1' \
    '/bin/rm src/Foo.php' \
    'sudo rm src/Foo.php' \
    'sudo -u www-data rm src/Foo.php' \
    'FOO=1 rm src/Foo.php' \
    'env -i rm src/Foo.php' \
    'find . -name "*.bak" | xargs rm' \
    'find . -name "*.bak" | xargs -I {} rm {}'
}

@test "file commands outside the project or without file arguments are allowed" {
  expect_allowed \
    'rm /tmp/scratch.txt' \
    'touch /tmp/marker' \
    'cp src/Foo.php /tmp/Foo.php.bak' \
    'mkdir -p /tmp/x && cp src/a.php /tmp/x/' \
    'cat x | tee' \
    'cat x | tee /dev/stderr' \
    'dd if=src/blob.bin of=/dev/null'
}

@test "in-place edits are writes" {
  expect_write \
    "sed -i 's/a/b/' src/Foo.php" \
    "sed -i.bak 's/a/b/' src/Foo.php" \
    "sed -Ei 's/a/b/' src/Foo.php" \
    "sed --in-place 's/a/b/' src/Foo.php" \
    "perl -pi -e 's/a/b/' src/Foo.php" \
    "perl -i -pe 's/a/b/' src/Foo.php" \
    "ruby -i -pe 'gsub(/a/, \"b\")' src/Foo.php"
}

@test "read-only sed and perl calls are allowed" {
  expect_allowed \
    "sed -n '1,20p' src/Foo.php" \
    "sed -E 's/a/b/' src/Foo.php" \
    "perl -ne 'print if /x/' src/Foo.php" \
    "perl -Mstrict -e 'print 1'"
}

@test "find with -delete or a writing -exec is a write" {
  expect_write \
    'find var/cache -type f -delete' \
    'find . -name "*.orig" -exec rm {} \;' \
    "find src -name '*.php' -exec sed -i 's/a/b/' {} +"
}

@test "find without writing actions is allowed" {
  expect_allowed \
    'find src -name "*.php"' \
    'find . -name "*.php" -exec grep -l Foo {} \;'
}

# --- git -------------------------------------------------------------------------

@test "git commands that change working tree files are writes" {
  expect_write \
    'git restore src/Foo.php' \
    'git checkout -- src/Foo.php' \
    'git checkout HEAD src/Foo.php' \
    'git checkout -f main' \
    'git reset --hard HEAD~1' \
    'git clean -fd' \
    'git apply fix.patch' \
    'git am < fix.mbox' \
    'git stash' \
    'git stash pop' \
    'git -C /some/repo restore x' \
    'git mv a.php b.php' \
    'git rm src/Old.php'
}

@test "read-only and history git commands are allowed" {
  expect_allowed \
    'git status' \
    'git diff --stat' \
    'git log --oneline -5' \
    'git show HEAD:src/Foo.php' \
    'git checkout -b feature/x' \
    'git checkout main' \
    'git reset HEAD src/Foo.php' \
    'git stash list' \
    'git add -A && git commit -m "wip"' \
    'git -c color.ui=never diff'
}

# --- frameworks and shells ------------------------------------------------------------

@test "Symfony maker commands are writes" {
  expect_write \
    'php bin/console make:entity Product' \
    'bin/console make:controller' \
    'symfony console make:migration'
}

@test "other Symfony console commands are allowed" {
  expect_allowed \
    'php bin/console debug:router' \
    'php bin/console cache:clear --env=test' \
    'symfony console lint:yaml config'
}

@test "PowerShell file cmdlets are writes" {
  expect_write \
    'Set-Content -Path src/Foo.php -Value x' \
    'Get-Content a | Out-File b.txt' \
    'remove-item src/Foo.php'
}

@test "writes are found in every part of a compound command" {
  expect_write \
    'cd src && rm Foo.php' \
    'composer test; rm -f src/Foo.php' \
    'true || touch failed.txt' \
    '(cd src; touch x)' \
    'echo $(rm src/Foo.php)' \
    'echo `touch x`' \
    'ls &
touch y'
}

@test "common read-only workflows are allowed" {
  expect_allowed \
    'ls -la src' \
    'cat src/Foo.php' \
    'grep -rn "class Foo" src' \
    'vendor/bin/phpunit --filter FooTest' \
    'composer validate' \
    'php -l src/Foo.php' \
    'jq .name composer.json' \
    'npm test' \
    'mkdir -p /tmp/claude-scratch'
}

@test "the reason names the detected pattern" {
  run ct_bash_write_reason "$P" "sed -i 's/a/b/' x"
  [ "$status" -eq 0 ]
  [ "$output" = "sed edits files in place" ]
  run ct_bash_write_reason "$P" 'echo x > src/A.php'
  [ "$output" = "output redirection to src/A.php" ]
}

@test "known limitation: code passed to an interpreter is not inspected" {
  # documented in README "Limitations"; this test pins the current behavior
  expect_allowed \
    "python3 -c 'open(\"src/Foo.php\", \"w\").write(\"x\")'" \
    "php -r 'file_put_contents(\"src/Foo.php\", \"x\");'" \
    "bash -c 'rm src/Foo.php'"
}

@test "brace groups, conditions and variable braces are handled" {
  expect_write \
    '{ rm src/Foo.php; }' \
    'if true; then touch src/x; fi' \
    '! rm src/Foo.php' \
    'while read f; do rm "$f"; done < list.txt'
  expect_allowed \
    'rm ${HOME}/scratch.txt' \
    'rm $HOME/scratch.txt' \
    '{ ls; pwd; }'
}

# The portable fallback runs where realpath has no -m (macOS, busybox). Where
# GNU realpath is available, both must agree.
@test "the portable realpath fallback matches GNU realpath -m" {
  realpath -m / >/dev/null 2>&1 || skip "GNU realpath -m not available"
  mkdir -p "$P/src/real" "$BATS_TEST_TMPDIR/outside"
  touch "$P/src/real/Foo.php"
  ln -s real "$P/src/link"
  ln -s src/real/Foo.php "$P/LEARNINGS.md"
  ln -s "$BATS_TEST_TMPDIR/outside" "$P/out"
  ln -s missing-target "$P/dangling"

  local path
  for path in \
    "$P" "$P/" "$P/src/real/Foo.php" "$P/src/link/Foo.php" "$P/src/link/New.php" \
    "$P/LEARNINGS.md" "$P/out/x.txt" "$P/dangling" "$P/new/dir/file.txt" \
    "$P/src/../src/./real//Foo.php" "$P/new/../x" "$P/src/link/../.." "/" "/tmp"; do
    if [ "$(ct__realpath_portable "$path")" != "$(realpath -m -- "$path")" ]; then
      echo "differs for $path: $(ct__realpath_portable "$path") vs $(realpath -m -- "$path")" >&2
      return 1
    fi
  done
}

@test "ct_realpath returns a single line even when realpath fails half way" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # a realpath that prints something and then fails, like busybox with -m
  printf '#!/bin/sh\necho "$3"\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/realpath"
  chmod +x "$BATS_TEST_TMPDIR/bin/realpath"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run ct_realpath "$P/src/Foo.php"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == */src/Foo.php ]]
}
