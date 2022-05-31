# devops-workitem-automation

### Template Format

currently supports json objects with following variables:
```json
{
  "type": "epic,feature...."
  "title: "..."
  "description": "..."
  "parentId": "..."
  "children": [
    {
      "type": "...."
      ....
    }
  ]
}
```

An object must have the values `type` and `title` whereas `description,parentId,children`are optional.
Furthermore should `parentId` only be held by the main object because all children are automatically linked to its parent.
