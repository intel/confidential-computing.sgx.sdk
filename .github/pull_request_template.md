<!-- Thanks for contributing to the Intel® SGX SDK! Fill in each section, replacing its guidance. -->
<!-- Give the PR a concise, imperative title above — e.g. "Fix X", "Add Y". -->

## Description
<!-- Explain *what* and *why*. This repo squash-merges by default — adopt a style you'd use for the commit-message body:
     - Use imperative mood, e.g. "Fix race in X" rather than "This PR fixes…" (and wrap overly long lines).
     - State the motivating use-case, and why you chose this approach over alternatives.
     - For a bug fix, give the root cause, not just the symptom.
     - Put reviewer-only notes that shouldn't land in the commit message under a `### Details` sub-heading. -->


## Type of change
<!-- Copy the one that applies:
     - Bug fix
     - Feature
     - Breaking (behavior/API/ABI/format)
     - Refactor/docs/tests/build
     - Other (describe)
     If Breaking, also fill *Backward compatibility* under Impact. -->


## Testing
<!-- How did you verify the changes introduced by this PR?
     - Bug fixes: please provide repro steps and the platform details (CPU, OS, driver) — see CONTRIBUTING.md for details.
     - Note the build modes exercised: hardware vs `SGX_MODE=SIM`, debug + release (mitigation flavors if relevant).
     - "Covered by CI" is fine for trivial changes — name the job.
     - Nothing to verify (e.g. a docs-only change)? Say so — a short "n/a: docs only" is enough. -->


## Impact
<!-- Replace each guidance comment below with one short line, or `n/a` where it doesn't apply. -->
- **Backward compatibility:** <!-- Note any break + migration needs, especially for: source/binary/ABI,
                              public headers & error codes, signed/on-disk/wire format, MRENCLAVE, config -->
- **Security:** <!-- Note any effect on security (e.g., TCB, attestation, crypto, trust boundary, side-channel/constant-time).
                Do NOT include exploit detail in a public PR; follow SECURITY.md -->
- **Dependencies / docs:** <!-- Note any: external/ submodule or third-party added/updated (name, version, license);
                           README/man/samples updated; one-line release note for a major change. -->


## Related issues / PRs
<!-- Link with GitHub keywords so issues auto-close on merge: Fixes #123, Refs #789.
     Linking other relevant issues/PRs will help the design converge faster, especially for a large
     or breaking change; reference to a prior discussion on the Intel SGX community forum helps too. -->
- `n/a`


## Checklist
<!-- Change `[ ]` to `[x]` for each item as you complete it (you can also tick them after opening the PR). -->
- [ ] I filled in the template above :point_up: — real input in the sections that apply, `n/a` where they don't.
- [ ] PR is focused on one thing; commits are atomic and signed off (`git commit -s`), per [`CONTRIBUTING.md`](https://github.com/intel/confidential-computing.sgx.sdk/blob/HEAD/CONTRIBUTING.md).
- [ ] Tests and docs are added/updated for the change (or noted `n/a` under *Impact*).
- [ ] I built the change and verified it works locally, or explained in *Testing* why CI alone is sufficient.
