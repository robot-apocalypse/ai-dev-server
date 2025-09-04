---
description: Apply this rule when editing any existing file, especially
  configuration files. It ensures that changes are based on the file's current
  state and are verified after the edit.
---

When asked to edit a file, first read the file using `read_file` to understand its current content and patterns. After using `edit_existing_file`, you MUST then use `read_file` again on the same file to confirm that your changes were applied correctly. Only after you have visually confirmed the change should you report success to the user.