# Figma API Cheatsheet

Auth header:
`X-Figma-Token: $FIGMA_TOKEN`

Read target node tree:
`GET https://api.figma.com/v1/files/{file_key}/nodes?ids={node_id}`

Get rendered image URLs:
`GET https://api.figma.com/v1/images/{file_key}?ids={id1,id2}&format=png&scale=2`

Useful URL parse:
- File key from path: `/design/{file_key}/...`
- Node id from query: `node-id=8022-205381` -> `8022:205381`
