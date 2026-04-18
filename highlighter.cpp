#include "highlighter.h"
#include <QQuickTextDocument>

highlighter::highlighter(QObject* parent)
    : QSyntaxHighlighter(parent)
{}

void highlighter::setDocument(QQuickTextDocument* doc) {
    if (doc)
        setDocument(doc->textDocument());
}

void highlighter::setLanguage(const QString& lang) {
    rules.clear();
    if (lang == "cpp" || lang == "c")
        loadCppRules();
    else if (lang == "java")
        loadJavaRules();
    else
        loadPlainRules();
    rehighlight();
}

// ─── Highlight entry point ────────────────────────────────────────────────────

void highlighter::highlightBlock(const QString& text) {
    // Apply single-line rules
    for (const Rule& rule : rules) {
        QRegularExpressionMatchIterator it = rule.pattern.globalMatch(text);
        while (it.hasNext()) {
            QRegularExpressionMatch match = it.next();
            setFormat(match.capturedStart(), match.capturedLength(), rule.format);
        }
    }

    // Multi-line comment handling
    setCurrentBlockState(0);

    int startIndex = 0;
    if (previousBlockState() != 1)
        startIndex = text.indexOf(commentStart);

    while (startIndex >= 0) {
        QRegularExpressionMatch endMatch = commentEnd.match(text, startIndex);
        int endIndex = endMatch.capturedStart();
        int length;
        if (endIndex == -1) {
            setCurrentBlockState(1);
            length = text.length() - startIndex;
        } else {
            length = endIndex - startIndex + endMatch.capturedLength();
        }
        setFormat(startIndex, length, multiLineCommentFormat);
        startIndex = text.indexOf(commentStart, startIndex + length);
    }
}

// ─── C / C++ rules ───────────────────────────────────────────────────────────

void highlighter::loadCppRules() {
    Rule rule;

    // Keywords
    QTextCharFormat keywordFormat;
    keywordFormat.setForeground(QColor("#569cd6")); // VS Code blue
    keywordFormat.setFontWeight(QFont::Bold);
    const QStringList keywords = {
        "alignas","alignof","and","and_eq","asm","auto","bitand","bitor",
        "bool","break","case","catch","char","char8_t","char16_t","char32_t",
        "class","compl","concept","const","consteval","constexpr","constinit",
        "const_cast","continue","co_await","co_return","co_yield","decltype",
        "default","delete","do","double","dynamic_cast","else","enum",
        "explicit","export","extern","false","float","for","friend","goto",
        "if","inline","int","long","mutable","namespace","new","noexcept",
        "not","not_eq","nullptr","operator","or","or_eq","private","protected",
        "public","register","reinterpret_cast","requires","return","short",
        "signed","sizeof","static","static_assert","static_cast","struct",
        "switch","template","this","thread_local","throw","true","try",
        "typedef","typeid","typename","union","unsigned","using","virtual",
        "void","volatile","wchar_t","while","xor","xor_eq","override","final"
    };
    for (const QString& kw : keywords) {
        rule.pattern = QRegularExpression("\\b" + kw + "\\b");
        rule.format  = keywordFormat;
        rules.append(rule);
    }

    // Preprocessor directives  (#include, #define, etc.)
    QTextCharFormat preprocFormat;
    preprocFormat.setForeground(QColor("#c586c0")); // purple
    rule.pattern = QRegularExpression("^\\s*#\\s*\\w+");
    rule.format  = preprocFormat;
    rules.append(rule);

    // Strings
    QTextCharFormat stringFormat;
    stringFormat.setForeground(QColor("#ce9178")); // orange-brown
    rule.pattern = QRegularExpression("\"([^\"\\\\]|\\\\.)*\"");
    rule.format  = stringFormat;
    rules.append(rule);

    // Char literals
    rule.pattern = QRegularExpression("'([^'\\\\]|\\\\.)*'");
    rule.format  = stringFormat;
    rules.append(rule);

    // Numbers (int, float, hex, binary, suffixes)
    QTextCharFormat numberFormat;
    numberFormat.setForeground(QColor("#b5cea8")); // light green
    rule.pattern = QRegularExpression(
        "\\b(0x[0-9A-Fa-f]+|0b[01]+|\\d+\\.?\\d*([eE][+-]?\\d+)?[fFlLuU]*)\\b"
        );
    rule.format = numberFormat;
    rules.append(rule);

    // Function calls
    QTextCharFormat funcFormat;
    funcFormat.setForeground(QColor("#dcdcaa")); // yellow
    rule.pattern = QRegularExpression("\\b([A-Za-z_][\\w]*)(?=\\s*\\()");
    rule.format  = funcFormat;
    rules.append(rule);

    // Types (capitalised identifiers — catches most class names)
    QTextCharFormat typeFormat;
    typeFormat.setForeground(QColor("#4ec9b0")); // teal
    rule.pattern = QRegularExpression("\\b[A-Z][A-Za-z0-9_]*\\b");
    rule.format  = typeFormat;
    rules.append(rule);

    // Single-line comment
    QTextCharFormat commentFormat;
    commentFormat.setForeground(QColor("#6a9955")); // green
    commentFormat.setFontItalic(true);
    rule.pattern = QRegularExpression("//[^\n]*");
    rule.format  = commentFormat;
    rules.append(rule);

    // Multi-line comment setup
    multiLineCommentFormat = commentFormat;
    commentStart = QRegularExpression("/\\*");
    commentEnd   = QRegularExpression("\\*/");
}

// ─── Java rules ──────────────────────────────────────────────────────────────

void highlighter::loadJavaRules() {
    Rule rule;

    // Keywords
    QTextCharFormat keywordFormat;
    keywordFormat.setForeground(QColor("#569cd6"));
    keywordFormat.setFontWeight(QFont::Bold);
    const QStringList keywords = {
        "abstract","assert","boolean","break","byte","case","catch","char",
        "class","const","continue","default","do","double","else","enum",
        "extends","final","finally","float","for","goto","if","implements",
        "import","instanceof","int","interface","long","native","new",
        "package","private","protected","public","return","short","static",
        "strictfp","super","switch","synchronized","this","throw","throws",
        "transient","try","var","void","volatile","while","record","sealed",
        "permits","yield","non-sealed"
    };
    for (const QString& kw : keywords) {
        rule.pattern = QRegularExpression("\\b" + kw + "\\b");
        rule.format  = keywordFormat;
        rules.append(rule);
    }

    // Annotations
    QTextCharFormat annotationFormat;
    annotationFormat.setForeground(QColor("#c586c0"));
    rule.pattern = QRegularExpression("@[A-Za-z_][\\w]*");
    rule.format  = annotationFormat;
    rules.append(rule);

    // Strings
    QTextCharFormat stringFormat;
    stringFormat.setForeground(QColor("#ce9178"));
    rule.pattern = QRegularExpression("\"([^\"\\\\]|\\\\.)*\"");
    rule.format  = stringFormat;
    rules.append(rule);

    // Text blocks (Java 15+)  """..."""
    rule.pattern = QRegularExpression("\"\"\".*?\"\"\"",
                                      QRegularExpression::DotMatchesEverythingOption);
    rule.format  = stringFormat;
    rules.append(rule);

    // Char literals
    rule.pattern = QRegularExpression("'([^'\\\\]|\\\\.)*'");
    rule.format  = stringFormat;
    rules.append(rule);

    // Numbers
    QTextCharFormat numberFormat;
    numberFormat.setForeground(QColor("#b5cea8"));
    rule.pattern = QRegularExpression(
        "\\b(0x[0-9A-Fa-f_]+|0b[01_]+|\\d[\\d_]*\\.?[\\d_]*([eE][+-]?[\\d_]+)?[fFdDlL]?)\\b"
        );
    rule.format = numberFormat;
    rules.append(rule);

    // Function/method calls
    QTextCharFormat funcFormat;
    funcFormat.setForeground(QColor("#dcdcaa"));
    rule.pattern = QRegularExpression("\\b([A-Za-z_][\\w]*)(?=\\s*\\()");
    rule.format  = funcFormat;
    rules.append(rule);

    // Types (capitalised)
    QTextCharFormat typeFormat;
    typeFormat.setForeground(QColor("#4ec9b0"));
    rule.pattern = QRegularExpression("\\b[A-Z][A-Za-z0-9_]*\\b");
    rule.format  = typeFormat;
    rules.append(rule);

    // Single-line comment
    QTextCharFormat commentFormat;
    commentFormat.setForeground(QColor("#6a9955"));
    commentFormat.setFontItalic(true);
    rule.pattern = QRegularExpression("//[^\n]*");
    rule.format  = commentFormat;
    rules.append(rule);

    // Javadoc tags inside comments
    QTextCharFormat javadocFormat;
    javadocFormat.setForeground(QColor("#608b4e"));
    javadocFormat.setFontItalic(true);
    rule.pattern = QRegularExpression("@(param|return|throws|see|author|version|since|deprecated)\\b");
    rule.format  = javadocFormat;
    rules.append(rule);

    multiLineCommentFormat = commentFormat;
    commentStart = QRegularExpression("/\\*");
    commentEnd   = QRegularExpression("\\*/");
}

// ─── Plain text (no highlighting) ────────────────────────────────────────────

void highlighter::loadPlainRules() {
    // intentionally empty
    commentStart = QRegularExpression("(?!x)x"); // never matches
    commentEnd   = QRegularExpression("(?!x)x");
}