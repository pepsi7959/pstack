---
description: pstack judge. Reads candidates, trails, and transcripts and scores them without editing. Use when a pstack skill asks for a judge or a reviewer from another vendor.
mode: subagent
permissions:
  - { action: "*", resource: "*", effect: deny }
  - { action: read, resource: "*", effect: allow }
  - { action: read, resource: "*.env", effect: deny }
  - { action: read, resource: "*.env.*", effect: deny }
  - { action: read, resource: "*.env.example", effect: allow }
  - { action: glob, resource: "*", effect: allow }
  - { action: grep, resource: "*", effect: allow }
  - { action: skill, resource: "*", effect: allow }
  - { action: external_directory, resource: "*", effect: allow }
---
