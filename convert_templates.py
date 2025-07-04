import os, openai, time, sys, re

IN_DIR = os.getenv("TEMPLATE_INPUT_DIR", "./templates_static")
OUT_DIR = os.getenv("TEMPLATE_OUTPUT_DIR", "./templates_jinja")
openai.api_key = os.getenv("OPENAI_API_KEY") or sys.exit("OPENAI_API_KEY not set.")

# Heuristic file type detector for better prompt customization
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

Objective: Convert the given static XHTML/HTML file into a flexible, reusable Jinja2 template, retaining layout, accessibility, and all CSS, but replacing all hardcoded content with semantic, clearly-named placeholders and Jinja2 blocks. Never remove or break structure/styles. Always comment on where dynamic content should go. Return only the new template code.
"""
    details = {
        "quiz_key": """
- This file is a quiz answer key.
- There are 16 chapters, each with 4 questions, totaling 64 answers.
- Create a repeatable structure (Jinja2 for loop) for answers: {% for answer in answers %}...{% endfor %}.
- Use placeholders like {{ answer.chapter }}, {{ answer.number }}, {{ answer.text }}.
""",
        "worksheet": """
- This file is an interactive worksheet.
- Use placeholders for user entries and worksheet sections.
- Use blocks for sections: {% block section_1 %}{% endblock %}, etc.
""",
        "chapter": """
- This file is a chapter content template.
- Use placeholders for chapter metadata (title, number, Bible quote, etc.).
- Use blocks for intro, main, worksheet, quiz, and quote.
""",
        "title": """
- This file is a title page.
- Use placeholders for title, subtitle, author, publisher, and cover image.
""",
        "toc": """
- This file is a table of contents.
- Use a Jinja2 for loop for chapters: {% for chapter in chapters %}...{% endfor %}.
""",
        "copyright": """
- This file is a copyright page.
- Use placeholders for copyright year, author, publisher, ISBN.
""",
        "about_author": """
- This file is an about the author page.
- Use placeholders for author name, bio, photo.
""",
        "general": """
- Generic content template.
- Replace all text, headings, and fixed elements with placeholders.
"""
    }
    return base + details.get(typ, details["general"])

def convert_with_openai(static_html, filetype):
    prompt = get_prompt_for_type(filetype) + "\n\nStatic Template File:\n\"\"\"\n" + static_html + "\n\"\"\"\n"
    for retry in range(3):
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4o", temperature=0.2, max_tokens=3072,
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
        output_path = os.path.join(OUT_DIR, fname)  # Keeps the same filename, no extra subdirectory
        print(f"Converting {fname} as type [{filetype}] ...")
        with open(input_path, "r", encoding="utf-8") as f:
            static_html = f.read()
        jinja_template = convert_with_openai(static_html, filetype)
        with open(output_path, "w", encoding="utf-8") as out:
            out.write(jinja_template)
        print(f"✓ Saved to {output_path}\n")

if __name__ == "__main__":
    main()
