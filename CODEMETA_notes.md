# CodeMeta 4.0 files for the two Mobiliscope repositories

Linda Angulo Lopez, 1 October 2026

Draft `codemeta.json` files added to the local clones, as untracked files (not committed, not pushed, not sent to the team):

- `www/codemeta.json` (copy in `codemeta/www.codemeta.json`)
- `data-process/codemeta.json` (copy in `codemeta/data-process.codemeta.json`)

Context: `https://w3id.org/codemeta/4.0`. Every property used is defined in the 4.0 context (checked against the context file on 1 October 2026). Two terms are specific to v4: `relatedSoftware`, which links the two repositories to each other, and `maintainer` / `funding`, which v4 maps to schema.org. schema.org types that the context does not alias (`Dataset`, `Grant`, `ScholarlyArticle`, `Periodical`, `WebPage`) are written with the `schema:` prefix. Not run through a JSON-LD processor (`pyld` is not installed here).

## Where each value comes from

| Field | Source |
|---|---|
| Authors of `www` | The citation model on the website and in the Zenodo readme (Vallée, Douet, Le Roux, Commenges, Lecomte, Villard) |
| Authors of `data-process` | The commit history (Douet, Vallée) and the header of `p2m.R`, which credits Constance Lecomte's original script |
| Contributors | Commit history and the team page (Renaud Bessières, Angelo Matte) |
| Maintainers | Team page: Julie Vallée is responsible for the project, Angelo Matte in charge of development since October 2025 |
| Version | `4.3` for `www` (site and release tags); `20230706` for `data-process` (its only tag) |
| Licence | `LICENSE` and readme files: AGPL-3.0 |
| Funding | LISST web page: CNRS Sciences humaines et sociales, SOSI programme, since 2025 |
| Data | Zenodo, doi:10.5281/zenodo.11111161, ODbL |
| Citation | Vallée and Lenormand 2024, the article the site presents as fully reproducible |
| Archive and identifier | Software Heritage, snapshot of the latest visit (3 March 2025) |

## For the team to decide, not me

- (i) **Authorship and order.** Who is an author, a contributor or a maintainer of each repository is the team's decision. The lists above are a reading of public sources.
- (ii) **Licence identifier.** The files say `AGPL-3.0-only`. The readme says "AGPL-3.0" without stating "only" or "or later".
- (iii) **Identifiers.** No ORCID for the people and no ROR for the organisations: I did not look them up, to avoid attaching a wrong identifier to a person.
- (iv) **Funding.** Only the SOSI programme is listed. Earlier funders and partners (Géographie-cités, Ined, Cerema, ANCT, LabEx) are not.
- (v) **Copyright holder.** Set to CNRS as a placeholder; the repositories do not state it.
- (vi) **SWHID.** The snapshot identifiers date from March 2025. They should be replaced after a new archive visit, at the next release.

Would the team rather keep one `codemeta.json` per repository, or one for the project with the two repositories as parts?
