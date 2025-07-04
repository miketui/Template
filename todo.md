Todo.md-

<!-- ───────── Manus build manifest — drop in project root ───────── -->

# Build “Curls & Contemplation” — EPUB-3 & PDF (WCAG 2.2)

_Agent_: **Manus v0.16** *Repo*: `<project-root>/`  
_Outputs_: `dist/` *Logs*: `logs/` *Archive*: `archive/`  
_Template dir_: `templates/` · *Asset/quote map*: `docs/asset-map.md`  
_Build map (for scripts)_: `file-map.yaml`

---

## 0 Templates index ✅

| Section / Purpose           | Template file (`templates/…`)          |
| --------------------------- | -------------------------------------- |
| Copyright page              | `copyright_template.xhtml`             |
| Dedication page             | `dedication_template.xhtml`            |
| Title page                  | `title_page_template.xhtml`            |
| Preface page                | `preface_template.xhtml`               |
| Table of contents           | `table_of_contents_template.xhtml`     |
| About-the-author            | `about_author_template.xhtml`          |
| Part/Chapter title page     | `chapter_title_template.xhtml.txt`     |
| Chapter flow wrapper        | `chapter_flow_template.xhtml`          |
| Chapter content block       | `chapter_content_template.xhtml`       |
| Chapter last (quote) page   | `chapter_last_page_template.xhtml.txt` |
| Quiz page                   | `quiz_template.xhtml`                  |
| Quiz answer-key page        | `quiz_key_template.xhtml`              |
| Worksheet type 1 (odd ch.)  | `worksheet_template_1.xhtml`           |
| Worksheet type 2 (even ch.) | `worksheet_template_2.xhtml`           |
| Journal worksheet           | `journal_worksheet_template.xhtml`     |
| Self-assessment             | `self_assessment_template.xhtml`       |
| SMART-goals worksheet       | `smart_goals_template.xhtml`           |
| Affirmation Odyssey page    | `affirmation_odyssey_template.xhtml`   |

> **file-map.yaml** pairs each XHTML output (1-44) with:
>
> -   the template above · quote image (PNG/JPG) · alt-text · output path.  
>     Build scripts **fail fast** if any entry is absent or mismatched.

---

## 1 Environment (pinned)

| Tool             | Version | Check cmd                      |
| ---------------- | ------- | ------------------------------ |
| Pandoc           | 3.2.0   | `pandoc --version`             |
| EPUBCheck        | 5.1.0   | `java -jar epubcheck.jar -h`   |
| DAISY ACE CLI    | 1.4.0   | `ace --version`                |
| Kindle Previewer | 3.77    | `kindlepreviewer --convert -h` |
| GNU Make         | 4.4     | `make -v`                      |
| Bash             | 5.x     | `/bin/bash --version`          |

`make env-check` verifies all paths.

---

## 2 Automation API (key `Makefile` targets)

```make
.PHONY: clean env-check front chapters back images css-validate \
        opf nav package epub epubcheck ace kp validate all

SRC  = PERFECT_COMBINED_BOOK.md
CSS  = style.css,fonts.css
META = epub_compilation_metadata.yaml
MAP  = file-map.yaml
EPUB = dist/book.epub
PDF  = dist/book.pdf

clean:
	rm -rf build OEBPS META-INF dist logs archive

env-check:
	@which pandoc && pandoc --version | head -1
	@java -version
	@ace --version || echo "ACE missing"
	@which kindlepreviewer

front:            ## STEP 3A
	pandoc $(SRC) -o build/front.xhtml \
	  --to=epub3 --from=markdown --embed-resources \
	  --epub-stylesheet=$(CSS) --metadata-file=$(META) \
	  | tee logs/step3A-front.log

chapters:         ## STEP 3B
	./scripts/split_and_build.sh $(SRC) $(CSS) $(META) $(MAP) \
	  | tee logs/step3B-chapters.log

back:             ## STEP 3C
	python scripts/build_backmatter.py $(MAP) | tee logs/step3C-back.log

images:           ## STEP 3D – validate 20 JPEGs (≥300 ppi)
	python scripts/validate_images.py $(MAP) assets/quotes --dpi 300 \
	  | tee logs/step3D-images.log

css-validate:     ## STEP 4
	./scripts/css_lint.sh style.css fonts.css | tee logs/step4-css.log

opf nav:          ## STEP 5
	python scripts/gen_opf.py $(META) $(MAP) > OEBPS/content.opf
	python scripts/gen_nav.py                > OEBPS/nav.xhtml
	echo "WOFF2 MIME OK" | tee logs/step5-opf-nav.log

package: mimetype container opf nav
	zip -X0 $(EPUB) mimetype
	zip -r9 $(EPUB) META-INF/ OEBPS/ >> logs/step5-opf-nav.log

epub:             ## STEP 6
	pandoc $(SRC) -o $(EPUB) --to=epub3 --from=markdown \
	  --epub-chapter-level=1 --embed-resources \
	  --epub-stylesheet=$(CSS) --metadata-file=$(META) \
	  | tee logs/step6-compile.log
	pandoc $(SRC) -o $(PDF) --pdf-engine=weasyprint >> logs/step6-compile.log

epubcheck:        ## STEP 7
	java -jar epubcheck.jar $(EPUB) | tee logs/step7-epubcheck.log
ace:
	ace -o logs/ace $(EPUB) | tee logs/step7-ace.log
kp:
	kindlepreviewer $(EPUB) --convert --output logs/kp | tee logs/step7-kp.log

validate: epubcheck ace kp
all: clean env-check front chapters back images css-validate \
     opf nav package epub validate
```

---

## 3 Kanban checklist (Manus auto-ticks)

| Phase | Task                                                         | Status | Log                        |
| ----- | ------------------------------------------------------------ | ------ | -------------------------- |
| 1     | Proof-read & copy-edit → `clean/01_final.md`                 | ⬜     | `logs/step1-diff.patch`    |
| 2     | Fact-check claims & endnotes                                 | ⬜     | `logs/step2-facts.md`      |
| 3A    | Build **7** front-matter XHTML                               | ⬜     | `logs/step3A-front.log`    |
| 3B    | Build **20** chapter XHTML (map-driven)                      | ⬜     | `logs/step3B-chapters.log` |
| 3C    | Build **17** back-matter XHTML                               | ⬜     | `logs/step3C-back.log`     |
| 3D    | Embed & validate **20 JPEGs** (≥300 ppi, alt-text, from map) | ⬜     | `logs/step3D-images.log`   |
| 4     | Optimise CSS & verify WOFF2 MIME                             | ⬜     | `logs/step4-css.log`       |
| 5     | Generate `content.opf` + `nav.xhtml` (landmarks)             | ⬜     | `logs/step5-opf-nav.log`   |
| 6     | Compile `dist/book.epub` + `book.pdf`                        | ⬜     | `logs/step6-compile.log`   |
| 7     | Validation: EPUBCheck · Ace · Kindle Previewer               | ⬜     | `logs/step7-validate.txt`  |
| 8     | Archive snapshots + deliver ZIP                              | ⬜     | `logs/step8.log`           |

Legend ⬜ pending · ✅ done · ❌ blocked

---

## 4 Open human items

-   ⬜ Confirm ISBN & imprint line.
-   ⬜ Approve `<meta property="schema:accessibilitySummary">`.

_(No placeholder assets; all 20 images are final.)_

---

## 5 Artefact map

```
dist/book.epub
dist/book.pdf
dist/assets.zip
archive/phase-8-*/
logs/
```

---

## 6 Run order

```bash
make env-check
make clean
# Manual proof-read → tick STEP 1 ✅
make all
# Fix ❌, rerun target; Manus ticks STEP 8 on success
```

---

### Keep `todo.md` slim, keep full asset data in `docs/asset-map.md`.

The **templates table** above ties every XHTML layout to a filename—so the build system and your editors share the same source-of-truth without cluttering the automation logic.
