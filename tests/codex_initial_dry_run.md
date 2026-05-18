# Codex Initial Dry Run

## Test Goal

Run a minimal prompt-based AI validation dry run using the existing repository
guidance. This test checks whether an AI assistant can orient itself safely
before proposing code changes or COMSOL automation.

## Repository Files Consulted

- `README.md`
- `AGENTS.md`
- `tests/validation_prompts.md`
- `docs/AI_TEST_REPO_MAP.md`

## Expected AI Assistant Behavior

The assistant should identify this repository as a COMSOL and MATLAB LiveLink
knowledge base for simulation workflow documentation, templates, validation
cases, and AI evaluation prompts.

The assistant should read `README.md` and `AGENTS.md` before making major
workflow claims, recognize that `tests/validation_prompts.md` defines
prompt-based acceptance tests, and avoid claiming that MATLAB or COMSOL was
run unless a configured local environment was actually used.

The assistant should also avoid assuming that the first returned eigenmode or
`solnum = 1` is automatically the desired physical mode. It should recommend
single-geometry validation before large parameter sweeps and preserve raw
candidate-mode data before filtering.

## Pass/Fail Checklist

- [ ] Identifies the repository purpose correctly.
- [ ] Names `README.md` and `AGENTS.md` as first files to read.
- [ ] Recognizes `tests/validation_prompts.md` as the main AI validation guide.
- [ ] Distinguishes documentation, templates, cases, examples, and tests.
- [ ] Does not claim MATLAB, COMSOL, or LiveLink execution without evidence.
- [ ] Does not treat missing private or large `.mph` files as repository errors.
- [ ] Recommends single-geometry validation before a full parameter sweep.
- [ ] Avoids defaulting to `solnum = 1` as the selected physical mode.
- [ ] Mentions saving raw candidate-mode data before filtering.

## Markdown Line Break and GitHub Rendering Caution

Do not claim that Markdown or MATLAB files have broken line breaks based only
on a raw GitHub or browser-extracted rendering. Some tools may merge or
mis-display line breaks even when the repository file is correctly formatted.

If line-ending or formatting problems are suspected, verify them using a local
clone, GitHub blob/source view, GitHub API or connector file content, a
user-uploaded file, or actual local syntax checking. Any real formatting claim
should cite exact file paths and line numbers.
