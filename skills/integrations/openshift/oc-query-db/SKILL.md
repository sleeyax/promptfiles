---
name: oc-query-db
description: Answer a question about a deployed database with read-only SQL, running the MariaDB/MySQL client inside its pod on OpenShift via oc. Optimized for use with a small local model.
argument-hint: "The question to answer, optionally naming the namespace or MariaDB resource"
disable-model-invocation: true
---

# Query a Database on OpenShift

Question: $ARGUMENTS

Follow the steps in order. Every query is logged, runs under the user's own `oc` login, and touches real data belonging to real people. When a step says to ask the user, ask — never guess.

## Allowed commands

- `oc whoami` and `oc project -q`.
- `oc get` and `oc describe` on pods and workloads in the target namespace.
- `oc exec` into the database pod, for exactly two commands: the `printenv` listing in step 3 and the query template in step 4.
- SQL that passes the checklist in step 6.

For anything else: tell the user the command and let them run it themselves.

## Step 1: Preflight

```bash
oc whoami >/dev/null
NS=$(oc project -q)
```

- If `oc whoami` fails: stop and ask the user to run `oc login`.
- Keep the `>/dev/null`: you only need the exit code, and the identity it would print is the user's, not yours to record.
- If the user named a namespace: set `NS` to that name instead.
- From here on, put `-n "$NS"` on every `oc` command. That leaves the user's own `oc` context untouched.

Done when `oc whoami` succeeded and `NS` is set.

## Step 2: Find the database pod

```bash
oc -n "$NS" get mariadb -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.currentPrimary}{"\n"}{end}'
```

Each output row is `<resource-name> <pod-name>`, where the pod is that resource's current primary.

- Exactly one row: use its pod.
- Several rows: filter with a command, never by judgment. Take the word the user used to name the database, lowercase it, and rerun the listing through a whole-word filter — this example is for the word `remi`:

  ```bash
  oc -n "$NS" get mariadb -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.currentPrimary}{"\n"}{end}' | grep -E "(^|[-_])remi([-_]|$)"
  ```

  Put the user's word where `remi` is; change nothing else in the regex. The filter keeps whole-word matches only: for `remi` it keeps `remi-backend-mariadb` and drops `remini-db`. Exactly one row survives: use its pod. Zero or several rows survive: list all the resources and ask the user which one.
- No rows: stop and report that the namespace has no MariaDB resource.

Then check the pod is running:

```bash
POD=<pod-name from above>
oc -n "$NS" get pod "$POD"
```

Done when `POD` is set and its STATUS column says `Running`.

## Step 3: Check the credentials exist

The pod's environment holds its own credentials, and the step 4 template reads them by itself. You only confirm they are there. List the variable **names** only:

```bash
oc -n "$NS" exec "$POD" -- sh -c 'printenv | cut -d= -f1 | grep -E "^(MARIADB|MYSQL)" | sort'
```

Keep the `cut -d= -f1`: it is what keeps the password values out of your transcript.

- Listing contains `MARIADB_PASSWORD` or `MARIADB_ROOT_PASSWORD`: continue.
- Neither: stop, show the user the listing, and ask how to authenticate.

Done when the listing shows one of those two password variables.

## Step 4: How to run a query

Every query in steps 5 and 6 runs through this template. Copy it byte-for-byte — the **only** text you ever change is the `<one SQL statement>` line inside the heredoc. Run it as one single command, with nothing chained before or after it.

```bash
oc -n "$NS" exec -i "$POD" -- sh -c 'MYSQL_PWD="${MARIADB_PASSWORD:-$MARIADB_ROOT_PASSWORD}" exec "$(command -v mariadb || command -v mysql)" --user="${MARIADB_USER:-root}" --connect-timeout=10 --table' <<'SQL'
START TRANSACTION READ ONLY;
<one SQL statement>;
SQL
```

The template adapts to any pod on its own, which is why it needs no editing:

- It uses the application user when the pod has one and falls back to `root`.
- It finds the client whether the image ships it as `mariadb` or `mysql`.
- It connects to no particular database, so in your SQL write every table as `<database>.<table>` — step 5 finds the database name.

Fixed rules:

- The SQL travels on stdin (the heredoc) and the password stays inside the pod, so neither ever appears on a command line or in shell history. The single quotes around the `sh -c` script make the pod, not your machine, expand the `$…` variables — keep them.
- Keep `START TRANSACTION READ ONLY;` as the first SQL line. The server then rejects writes even if a bad statement slips past your review.

Output flags: `--table` prints a readable grid; use `-B` instead for tab-separated output you want to post-process; end a statement with `\G` instead of `;` for one-field-per-line output on wide rows.

## Step 5: Learn the schema

Run these through the step 4 template, in order, skipping what you already know:

1. `SHOW DATABASES;` — ignore `information_schema`, `mysql`, `performance_schema`, and `sys`; the remaining names are the candidates.
   - Exactly one candidate: use it.
   - Several candidates: filter with a query, never by judgment. Run this through the template, with the user's word in place of `remi` and nothing else changed: `SELECT schema_name FROM information_schema.schemata WHERE schema_name REGEXP '(^|[_-])remi([_-]|$)';` — it returns whole-word matches only (`remi`, `remi_backend`; never `remini`). Exactly one row: use it. Zero or several rows: list the candidates and ask the user which one.
2. `SHOW TABLES FROM <database>;` — find the table the question is about.
3. `SHOW CREATE TABLE <database>.<table>;` — get the exact column names before writing a query that uses them.

If the application's codebase is at hand — ORM entities, migrations, a checked-in schema dump — read it too, but only to understand what a column means (enum values, units, conventions), never for which columns exist: the checkout may be newer or older than what is deployed, so the pod's `SHOW CREATE TABLE` output is the truth on any mismatch.

Done when you know the database, table, and column names your query needs.

## Step 6: Write and run the query

Check the statement against every item:

- [ ] It starts with `SELECT`, `SHOW`, `DESCRIBE`, or `EXPLAIN`.
- [ ] It is a single statement, with no `;` inside it.
- [ ] Every table is written as `<database>.<table>`.
- [ ] It has no `INTO OUTFILE` and no `INTO DUMPFILE` clause — those write to disk despite starting with `SELECT`.
- [ ] It contains no password or secret value — the server logs every statement.
- [ ] It has a `LIMIT` (use `LIMIT 100` if you have no better bound).
- [ ] It names only the columns you need.

Every box checked:

1. First data query of the session only: print the exact SQL and wait for the user to confirm. The schema queries in step 5 need no confirmation, and neither do later data queries in the same session.
2. Run it through the step 4 template.

Any box unchecked: rewrite the statement first.

If the result is empty: run the step 5 `SHOW TABLES` query again and look for a similarly named table before reporting the data as absent.

## Step 7: Report

Answer the user's question in prose, with a small table of the rows that matter.

- Say which namespace and pod you queried, and show the SQL you ran.
- Include only the rows that answer the question, and keep them in the conversation — the chat is the deliverable, so write them to no file.

## Troubleshooting

| Error | Fix |
| --- | --- |
| `error: unable to upgrade connection` or `pods ... not found` | Check the pod name and namespace with `oc -n "$NS" get pods`. |
| `Access denied for user` | The pod uses non-standard credential variables. Show the user the step 3 listing and ask which to use. |
| `ERROR 1046 ... No database selected` | A table name is missing its `<database>.` prefix. Qualify it and rerun. |
| `ERROR 1792 ... READ ONLY transaction` | The statement tried to write. Stop and report it to the user. |
| `exec: not found` or `unable to start container process` | You are in the wrong container. List them with `oc -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[*].name}'` and add `-c <database container>` to both `oc exec` commands. |
