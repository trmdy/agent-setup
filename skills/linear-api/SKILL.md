---
name: linear-api
description: Interact with Linear's GraphQL API for issue/project/team reads and writes. Use when agents need deterministic Linear data operations (list/search issues, create/update issues, inspect workflow state, or sync metadata) and must resolve API credentials from Hem project secrets, defaulting to project/digitech/linear.
metadata:
  short-description: Operate Linear GraphQL with hem secrets
---

# Linear API

Use this skill for terminal-first Linear GraphQL calls with Hem-managed secrets.

## Required Inputs
- Query or mutation (`.graphql` file preferred).
- Optional variables JSON object file.
- Secret ref target: default `project/digitech/linear`.

## Workflow
1. Preflight:
- `hem examples --format json`
- `hem search 'project/*/linear'`
- Confirm exact ref to use (`project/digitech/linear` by default).

2. Resolve token:
- Use `hem get project/digitech/linear`.
- Parse `api_key=` value only.
- Never print token in logs or chat output.
- If response contains `pending_request_id`, stop and ask human for approval receipt.

3. Execute GraphQL:
- Save operation in a file, then run:
`scripts/linear_graphql.sh --query-file /tmp/query.graphql`
- With variables:
`scripts/linear_graphql.sh --query-file /tmp/query.graphql --variables-file /tmp/vars.json`
- Override secret scope when needed:
`scripts/linear_graphql.sh --project digitech --secret linear --query-file /tmp/query.graphql`

4. Validate response:
- Ensure JSON has no top-level `errors`.
- For mutations, report identifiers and status fields changed.

## Common Operations
- Read viewer / auth check.
- List issues by team/state.
- Create issue with title, teamId, description.
- Update issue fields (state, assignee, labels, due date).

Read query templates in `references/common-queries.md`.

## Output Contract
Return:
1. Secret ref used (never token).
2. Operation goal (read/mutation + entity).
3. Key fields from `data`.
4. Any GraphQL errors and next fix step.
