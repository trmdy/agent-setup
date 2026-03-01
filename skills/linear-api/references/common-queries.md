# Linear GraphQL Query Templates

## Viewer Check

```graphql
query Viewer {
  viewer {
    id
    name
    email
  }
}
```

## Teams List

```graphql
query Teams {
  teams {
    nodes {
      id
      key
      name
    }
  }
}
```

## Issues by Team

```graphql
query TeamIssues($teamId: String!, $first: Int = 20) {
  issues(
    filter: { team: { id: { eq: $teamId } } }
    first: $first
    orderBy: updatedAt
  ) {
    nodes {
      id
      identifier
      title
      priority
      state {
        id
        name
        type
      }
      assignee {
        id
        name
      }
      updatedAt
    }
  }
}
```

Variables example:

```json
{
  "teamId": "YOUR_TEAM_ID",
  "first": 20
}
```

## Create Issue

```graphql
mutation CreateIssue($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue {
      id
      identifier
      title
      url
    }
  }
}
```

Variables example:

```json
{
  "input": {
    "teamId": "YOUR_TEAM_ID",
    "title": "Example issue from API",
    "description": "Created via GraphQL helper"
  }
}
```

## Update Issue State

```graphql
mutation UpdateIssue($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    success
    issue {
      id
      identifier
      title
      state {
        id
        name
        type
      }
      updatedAt
    }
  }
}
```
