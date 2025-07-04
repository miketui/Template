#!/bin/bash

# EPUB Publishing Tools Setup Script

# Sets up all tools needed for professional EPUB 3 creation and validation

# Compatible with macOS, Linux, and Windows (via WSL/Git Bash)

set -e  # Exit on any error

echo “🚀 Setting up EPUB Publishing Toolchain…”
echo “This will install: Pandoc, EPUBCheck, DAISY ACE, and Kindle Previewer”
echo “”

# Detect OS

OS=””
if [[ “$OSTYPE” == “linux-gnu”* ]]; then
OS=“linux”
elif [[ “$OSTYPE” == “darwin”* ]]; then
OS=“macos”
elif [[ “$OSTYPE” == “msys” ]] || [[ “$OSTYPE” == “cygwin” ]]; then
OS=“windows”
else
echo “❌ Unsupported OS: $OSTYPE”
exit 1
fi

echo “🔍 Detected OS: $OS”
echo “”

# Create tools directory

TOOLS_DIR=”$HOME/epub-tools”
mkdir -p “$TOOLS_DIR”
cd “$TOOLS_DIR”

echo “📁 Created tools directory: $TOOLS_DIR”
echo “”

# 1. Install Pandoc >= 3.2

echo “📚 Installing Pandoc…”
if command -v pandoc &> /dev/null; then
PANDOC_VERSION=$(pandoc –version | head -n1 | cut -d’ ’ -f2)
echo “✅ Pandoc already installed (version $PANDOC_VERSION)”
else
case $OS in
“macos”)
if command -v brew &> /dev/null; then
brew install pandoc
else
echo “🍺 Installing Homebrew first…”
/bin/bash -c “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)”
brew install pandoc
fi
;;
“linux”)
# Install latest Pandoc from GitHub releases
PANDOC_URL=$(curl -s https://api.github.com/repos/jgm/pandoc/releases/latest | grep “browser_download_url.*linux-amd64.tar.gz” | cut -d ‘”’ -f 4)
wget -O pandoc.tar.gz “$PANDOC_URL”
tar -xzf pandoc.tar.gz
sudo cp pandoc-*/bin/pandoc /usr/local/bin/
rm -rf pandoc*
;;
“windows”)
echo “⚠️  Please download Pandoc manually from: https://pandoc.org/installing.html”
echo “   Or use: winget install JohnMacFarlane.Pandoc”
;;
esac
fi

# 2. Install Java (required for EPUBCheck and DAISY ACE)

echo “”
echo “☕ Checking Java installation…”
if command -v java &> /dev/null; then
JAVA_VERSION=$(java -version 2>&1 | head -n1 | cut -d’”’ -f2)
echo “✅ Java already installed (version $JAVA_VERSION)”
else
case $OS in
“macos”)
brew install openjdk@11
echo ‘export PATH=”/opt/homebrew/opt/openjdk@11/bin:$PATH”’ >> ~/.zshrc
;;
“linux”)
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk
;;
“windows”)
echo “⚠️  Please install Java 11+ from: https://adoptium.net/”
;;
esac
fi

# 3. Install Node.js (required for DAISY ACE)

echo “”
echo “🟢 Checking Node.js installation…”
if command -v node &> /dev/null; then
NODE_VERSION=$(node –version)
echo “✅ Node.js already installed (version $NODE_VERSION)”
else
case $OS in
“macos”)
brew install node
;;
“linux”)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
;;
“windows”)
echo “⚠️  Please install Node.js from: https://nodejs.org/”
;;
esac
fi

# 4. Install EPUBCheck 5.x

echo “”
echo “📖 Installing EPUBCheck…”
EPUBCHECK_VERSION=“5.1.0”
EPUBCHECK_URL=“https://github.com/w3c/epubcheck/releases/download/v${EPUBCHECK_VERSION}/epubcheck-${EPUBCHECK_VERSION}.zip”

if [ ! -f “epubcheck-${EPUBCHECK_VERSION}/epubcheck.jar” ]; then
wget -O epubcheck.zip “$EPUBCHECK_URL”
unzip epubcheck.zip
rm epubcheck.zip
echo “✅ EPUBCheck installed”
else
echo “✅ EPUBCheck already installed”
fi

# Create EPUBCheck wrapper script

cat > epubcheck << ‘EOF’
#!/bin/bash
SCRIPT_DIR=”$(cd “$(dirname “${BASH_SOURCE[0]}”)” && pwd)”
java -jar “$SCRIPT_DIR/epubcheck-5.1.0/epubcheck.jar” “$@”
EOF
chmod +x epubcheck

# 5. Install DAISY ACE

echo “”
echo “♿ Installing DAISY ACE (Accessibility Checker)…”
if command -v ace &> /dev/null; then
echo “✅ DAISY ACE already installed”
else
npm install -g @daisy/ace
echo “✅ DAISY ACE installed”
fi

# 6. Download Kindle Previewer

echo “”
echo “📱 Setting up Kindle Previewer…”
case $OS in
“macos”)
echo “📥 Download Kindle Previewer from: https://kdp.amazon.com/en_US/help/topic/G202131170”
echo “   (Manual download required for macOS)”
;;
“linux”)
echo “📥 Download Kindle Previewer from: https://kdp.amazon.com/en_US/help/topic/G202131170”
echo “   (Manual download required for Linux)”
;;
“windows”)
echo “📥 Download Kindle Previewer from: https://kdp.amazon.com/en_US/help/topic/G202131170”
echo “   (Manual download required for Windows)”
;;
esac

# 7. Add tools to PATH

echo “”
echo “🔧 Setting up PATH…”
BASHRC_FILE=””
case $OS in
“macos”)
BASHRC_FILE=”$HOME/.zshrc”
;;
*)
BASHRC_FILE=”$HOME/.bashrc”
;;
esac

# Add tools directory to PATH if not already there

if ! grep -q “$TOOLS_DIR” “$BASHRC_FILE” 2>/dev/null; then
echo “” >> “$BASHRC_FILE”
echo “# EPUB Publishing Tools” >> “$BASHRC_FILE”
echo “export PATH="$TOOLS_DIR:$PATH"” >> “$BASHRC_FILE”
echo “✅ Added tools to PATH in $BASHRC_FILE”
else
echo “✅ Tools already in PATH”
fi

# 8. Create validation script

echo “”
echo “🧪 Creating EPUB validation script…”
cat > validate-epub << ‘EOF’
#!/bin/bash

# EPUB Validation Script - runs all required checks

if [ $# -eq 0 ]; then
echo “Usage: validate-epub <epub-file>”
exit 1
fi

EPUB_FILE=”$1”
BASENAME=$(basename “$EPUB_FILE” .epub)

echo “🔍 Validating EPUB: $EPUB_FILE”
echo “”

# EPUBCheck validation

echo “📖 Running EPUBCheck…”
java -jar “$(dirname “$0”)/epubcheck-5.1.0/epubcheck.jar” “$EPUB_FILE” > “${BASENAME}_epubcheck.log” 2>&1
if [ $? -eq 0 ]; then
echo “✅ EPUBCheck: PASSED”
else
echo “❌ EPUBCheck: FAILED (see ${BASENAME}_epubcheck.log)”
fi

# DAISY ACE accessibility check

echo “”
echo “♿ Running DAISY ACE accessibility check…”
ace “$EPUB_FILE” -o “${BASENAME}_ace_report” > “${BASENAME}_ace.log” 2>&1
if [ $? -eq 0 ]; then
echo “✅ DAISY ACE: PASSED”
echo “   Report saved to: ${BASENAME}_ace_report”
else
echo “❌ DAISY ACE: FAILED (see ${BASENAME}_ace.log)”
fi

echo “”
echo “🎉 Validation complete!”
echo “Next: Test in Kindle Previewer manually”
EOF
chmod +x validate-epub

# 9. Create EPUB build script template

echo “”
echo “🔨 Creating EPUB build script template…”
cat > build-epub << ‘EOF’
#!/bin/bash

# EPUB Build Script Template

# Configuration

MANUSCRIPT=“PERFECT_COMBINED_BOOK.md”
METADATA=“epub_compilation_metadata.yaml”
OUTPUT_DIR=“output”
EPUB_NAME=“my-book.epub”

echo “🚀 Building EPUB from manuscript…”

# Create output directory

mkdir -p “$OUTPUT_DIR”

# Build EPUB with Pandoc

pandoc “$MANUSCRIPT”   
–from markdown   
–to epub3   
–epub-chapter-level=1   
–embed-resources   
–metadata-file=”$METADATA”   
–css=style.css   
–css=fonts.css   
–toc   
–toc-depth=3   
–output=”$OUTPUT_DIR/$EPUB_NAME”

if [ $? -eq 0 ]; then
echo “✅ EPUB built successfully: $OUTPUT_DIR/$EPUB_NAME”
echo “”
echo “🔍 Running validation…”
./validate-epub “$OUTPUT_DIR/$EPUB_NAME”
else
echo “❌ EPUB build failed”
exit 1
fi
EOF
chmod +x build-epub

# 10. Verify installation

echo “”
echo “✅ Installation complete! Verifying tools…”
echo “”

# Check Pandoc

if command -v pandoc &> /dev/null; then
echo “✅ Pandoc: $(pandoc –version | head -n1)”
else
echo “❌ Pandoc: Not found”
fi

# Check Java

if command -v java &> /dev/null; then
echo “✅ Java: $(java -version 2>&1 | head -n1)”
else
echo “❌ Java: Not found”
fi

# Check Node.js

if command -v node &> /dev/null; then
echo “✅ Node.js: $(node –version)”
else
echo “❌ Node.js: Not found”
fi

# Check DAISY ACE

if command -v ace &> /dev/null; then
echo “✅ DAISY ACE: $(ace –version)”
else
echo “❌ DAISY ACE: Not found”
fi

# Check EPUBCheck

if [ -f “epubcheck-5.1.0/epubcheck.jar” ]; then
echo “✅ EPUBCheck: v5.1.0”
else
echo “❌ EPUBCheck: Not found”
fi

echo “”
echo “🎉 Setup complete!”
echo “”
echo “📁 Tools installed in: $TOOLS_DIR”
echo “🔧 Scripts created:”
echo “   • validate-epub - Validates EPUB files”
echo “   • build-epub - Template for building EPUBs”
echo “”
echo “🔄 Restart your terminal or run: source $BASHRC_FILE”
echo “”
echo “📖 Next steps:”
echo “1. Place your manuscript and assets in a project directory”
echo “2. Customize the build-epub script for your project”
echo “3. Run: ./build-epub”
echo “4. Manual step: Test in Kindle Previewer”
