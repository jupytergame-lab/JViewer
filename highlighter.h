#pragma once
#include <QSyntaxHighlighter>
#include <QTextCharFormat>
#include <QRegularExpression>

class highlighter : public QSyntaxHighlighter
{
    Q_OBJECT

public:
    explicit highlighter(QObject* parent = nullptr);

    Q_INVOKABLE void setLanguage(const QString& lang);
    Q_INVOKABLE void setDocument(QTextDocument* doc);

protected:
    void highlightBlock(const QString& text) override;

private:
    struct Rule {
        QRegularExpression pattern;
        QTextCharFormat format;
    };

    void loadCppRules();
    void loadJavaRules();
    void loadPlainRules();

    QList<Rule> rules;

    // Multi-line comment state
    QRegularExpression commentStart;
    QRegularExpression commentEnd;
    QTextCharFormat multiLineCommentFormat;
};