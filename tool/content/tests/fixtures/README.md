# PDF extraction fixtures

`pdf-books-layout.json.gz` contains visible glyphs, horizontal rules, image metadata,
and extracted text from 27 pages of the user-provided PDFs. It is a test fixture,
not an approved vocabulary or redistributed learning pack.

- `sarang-csat-2000`: physical pages 5, 6, 7, 10, 11, 16, 21, 27, 134, 411, 606.
  SHA-256: `6f67f6c820a72c96e38d09acf20f4df1e2b69e2e465bc78f0384cdbe1e7a0177`.
- `ebs-middle-excerpt`: physical pages 1, 2, 3, 11, 22, 23, 24, 25, 31, 35,
  39, 46, 47, 48, 49, 67.
  SHA-256: `87a3f8631df4132361b028a78a6bbe42964e47c86520db58eb03fe2d06a29785`.

The layout records use `tool.content.pdf_books.cache_layout`. The cases cover
off-page duplicate text, mixed fonts, three-digit printed numbering, bottom-of-page
translations, article A vs. answer markers, inflections and multiple blanks,
related-word colors, production footers, mismatched original Day labels,
half-specific tests, and multi-column etymology diagrams.

Source copies and transcription corrections live in `content/sources/user-provided`.
See `docs/pdf-content-import.md` for the source scope and review status.
