import os
import openai
import time
import sys

IN_DIR = os.getenv("TEMPLATE_INPUT_DIR", "./templates_static")
OUT_DIR = os.getenv("TEMPLATE_OUTPUT_DIR", "./templates_jinja")
openai.api_key = os.getenv("OPENAI_API_KEY") or sys.exit("OPENAI_API_KEY not set.")

def classify_template(fname):
    fname_lower = fname.lower()
    if "quiz" in fname_lower or "quiz-key" in fname_lower:
        return "quiz_key"
    if "worksheet" in fname_lower:
        return "worksheet"
    if "chapter" in fname_lower:
        return "chapter"
    if "title" in fname_lower:
        return "title"
    if "toc" in fname_lower or "contents" in fname_lower:
        return "toc"
    if "copyright" in fname_lower:
        return "copyright"
    if "about" in fname_lower or "author" in fname_lower:
        return "about_author"
    return "general"

def get_prompt_for_type(typ):
    base = """
Role: Expert Jinja2 Template Engineer and Content Modeler.

Objective: Convert the given static XHTML/HTML file into a flexible, reusable Jinja2 template, retaining all structure, CSS, and accessibility, but replacing all hardcoded content with clear, semantic placeholders and Jinja2 blocks. Comment clearly where dynamic content goes. Ensure the output will NOT produce linting errors and is ready for automated AI-driven content filling.
"""
    details = {
        "quiz_key": """
- This file is a quiz answer key (16 chapters × 4 answers = 64).
- Use a repeatable structure: {% for answer in answers %}…{% endfor %}.
- Placeholders: {{ answer.chapter }}, {{ answer.number }}, {{ answer.text }}.
""",
        "worksheet": """
- This file is an interactive worksheet.
- Use placeholders for user entries and worksheet sections.
- Use blocks for major sections.
""",
        "chapter": """
- This file is a chapter template.
- Placeholders: chapter title, number, bible quote, intro, main content, worksheet, quiz, quote image.
- Use Jinja2 blocks for intro, main, worksheet, quiz, and quote.
""",
        "title": """
- This file is a title page.
- Placeholders for title, subtitle, author, publisher, cover image.
""",
        "toc": """
- Table of contents file.
- Use a for-loop: {% for chapter in chapters %}…{% endfor %}.
""",
        "copyright": """
- Copyright page.
- Placeholders for year, author, publisher, ISBN.
""",
        "about_author": """
- About the author page.
- Placeholders for author name, bio, photo.
""",
        "general": """
- Generic template: replace all text, headings, and fixed elements with placeholders.
"""
    }
    return base + details.get(typ, details["general"])

def convert_with_openai(static_html, filetype):
    prompt = get_prompt_for_type(filetype) + "\n\nStatic Template File:\n\"\"\"\n" + static_html + "\n\"\"\"\n"
    for retry in range(3):
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4o",
                temperature=0.15,
                max_tokens=3072,
                messages=[{"role": "user", "content": prompt}]
            )
            return resp['choices'][0]['message']['content'].strip()
        except openai.error.OpenAIError as e:
            print(f"OpenAI API error: {e}. Retrying in 10 seconds...")
            time.sleep(10)
    raise RuntimeError("Failed to convert after 3 attempts.")

def main():
    for fname in os.listdir(IN_DIR):
        if not (fname.endswith(".html") or fname.endswith(".xhtml")):
            continue
        filetype = classify_template(fname)
        input_path = os.path.join(IN_DIR, fname)
        output_path = os.path.join(OUT_DIR, fname)
        print(f"Converting {fname} as type [{filetype}] …")
        with open(input_path, "r", encoding="utf-8") as f:
            static_html = f.read()
        jinja_template = convert_with_openai(static_html, filetype)
        # Lint the result with HTMLHint before saving
        with open("._tmp_jinja.xhtml", "w", encoding="utf-8") as tmp:
            tmp.write(jinja_template)
        lint_result = os.system(f"htmlhint ._tmp_jinja.xhtml")
        if lint_result != 0:
            print(f"⚠️  HTMLHint found issues in {fname}. Please review the output before using.")
        os.rename("._tmp_jinja.xhtml", output_path)
        print(f"✓ Saved to {output_path}\n")

if __name__ == "__main__":
    main()
