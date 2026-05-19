# CTAN Upload Research — 2026-05-18

## Source
Searched: ctan.org, GitHub, tug.org, CTAN upload documentation, TDS guidelines

---

## Required Files

| File | Required | Notes |
|------|----------|-------|
| `swarmwrap.sty` | MANDATORY | Already exists, has `\ProvidesPackage` header |
| `README.md` | MANDATORY | Needs proper CTAN-format README (we have release/README.md but it's minimal) |
| `swarmwrap-doc.pdf` | MANDATORY | User-facing PDF documentation — DOES NOT EXIST YET |
| Documentation source (.tex) | Recommended | TeX Live can't redistribute PDF without source |

## Files NOT to include
- `.aux`, `.log`, `.toc`, `_minted-*`, `.git/*`, `.DS_Store`
- Generated/compiled artifacts of any kind

## Archive Format
```
swarmwrap.zip:
  swarmwrap/
    README.md              ← CTAN-format README
    swarmwrap.sty          ← the package
    swarmwrap-doc.pdf      ← user documentation
    swarmwrap-doc.tex      ← source for documentation
```
- Accepted: `.zip`, `.tgz`, `.tar.gz`
- Top-level dir MUST be named exactly `swarmwrap`
- All filenames: 7-bit ASCII, start with a letter, no spaces

## License
- **Recommended: LPPL 1.3c** (standard for LaTeX packages)
- Also accepted: MIT, GPL3, BSD, Apache 2.0, CC0
- Must be stated in README, .sty header, AND upload form
- For TeX Live inclusion: must be free software

## Upload Process
1. **Validate** (optional): POST to `https://www.ctan.org/submit/validate`
2. **Upload**: Go to https://ctan.org/upload or use API/GitHub Action
3. **Wait**: CTAN team processes in hours to 1-2 days
4. **Appears on CTAN**: After approval
5. **Picked up by TeX Live**: ~1-2 days after CTAN appearance
6. **Available via `tlmgr install swarmwrap`**

No account or sponsor required — anyone can self-upload.

## GitHub Action for Automated Updates
**`paolobrasolin/ctan-submit-action`** (recommended):
- Triggers on git tags (`v*`)
- Validates and uploads to CTAN via API
- Supports both new packages and updates
- Marketplace: https://github.com/marketplace/actions/ctan-submit

## CTAN Path
Standard: `/macros/latex/contrib/swarmwrap`

## Naming
- Package name: `swarmwrap` (already compliant)
- Must be lowercase ASCII letters, digits, `-`, `_`
- Max 32 chars, must start with letter
- Version: semver recommended (e.g., `3.5.0`)

## Validation Tools
- **CTAN `pkgcheck`**: automated validation (used by CTAN team)
- **Pre-submission**: POST to validate endpoint
- **`l3build check`**: alternative for l3build-based packages

## Readiness Assessment for swarmwrap

### What we HAVE:
- ✅ `swarmwrap.sty` with proper `\ProvidesPackage` header
- ✅ Basic README.md in release/ (needs CTAN-format upgrade)
- ✅ Tests and demo documents
- ✅ Version 3.5 released

### What we NEED before uploading:
- ❌ **PDF documentation** (`swarmwrap-doc.pdf`) — user-facing manual with API reference, examples, limitations
- ❌ **CTAN-format README.md** — needs proper license statement, installation instructions, dependencies
- ❌ **License declaration** in .sty header (currently no license mentioned)
- ❌ **Documentation source** (.tex file for the PDF)
- ❌ **Archive packaging** (swarmwrap.zip with correct structure)

## Key URLs
| Resource | URL |
|----------|-----|
| Upload form | https://ctan.org/upload |
| Upload guide | https://ctan.org/help/upload-pkg |
| README help | https://ctan.org/help/pkg-readme |
| TDS guidelines | https://ctan.org/TDS-guidelines |
| License list | https://ctan.org/license |
| TeX Live contribution | https://tug.org/texlive/pkgcontrib.html |
| ctan-submit-action | https://github.com/marketplace/actions/ctan-submit |
