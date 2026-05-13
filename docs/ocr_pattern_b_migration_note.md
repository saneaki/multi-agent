# Pattern B OCR Migration Note (cmd_723)

Pattern B OCR has moved out of shogun.

- New repository: <https://github.com/saneaki/legal-pdf-ocr>
- Visibility: private
- Source: shogun `cmd_721`, commit `f2f2583`
- Release: `v1.0.0`

## Windows Clone

```powershell
git clone https://github.com/saneaki/legal-pdf-ocr.git
```

Then run:

```powershell
cd legal-pdf-ocr
.\setup_pattern_b.ps1
.\ocr_watch_start.ps1 -WatchDir "$env:USERPROFILE\Google Drive\My Drive\OCR\input"
```

shogun no longer carries the Pattern B runtime scripts. Use
`saneaki/legal-pdf-ocr` for setup, operation, bug fixes, and future OCR
development.
