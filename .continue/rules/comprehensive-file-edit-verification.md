---
description: This rule is an enhancement of the 'Verify File Edits' rule. It
  requires a more robust check after editing a file to prevent accidental
  deletions or malformations.
---

When asked to edit a file, first read the entire file using `read_file`. After using `edit_existing_file`, you MUST use `read_file` again to get the complete, updated content. Then, mentally (or with a tool if available) compare the new content to the old content to ensure not only that your addition was made, but that no other parts of the file were accidentally removed or altered. Pay special attention to the lines immediately surrounding your change. Only after this comprehensive verification can you report success.