---
description: "Format for the Pull request overview that automated review produces for any change in this repository."
applyTo: "**"
---
# Pull request overview format

When you produce a **Pull request overview** for a change in this repository,
follow this structure exactly:

- Start with the fixed heading `## Pull request overview`.
- The **first sentence** of the first paragraph is a commit‑title‑worthy summary:
  maximally informative, ideally ≤ 50 characters (soft-max 72). Continue the same paragraph with
  your usual informative sentences.
- Then a `**Changes:**` section as a hyphen‑bulleted list, written like a commit
  description: minimize churn, focus on what matters, aim for ~72 characters per
  line (wrapping a bullet onto the next line is fine). It should be copy‑pasteable
  into a commit message.
- Then a horizontal rule `---` (or a new heading, whichever reads better), after
  which you have free rein for the usual richer overview — detailed change
  descriptions and what was and wasn't reviewed. Don't repeat the section above
  verbatim, but you may add more fidelity.
