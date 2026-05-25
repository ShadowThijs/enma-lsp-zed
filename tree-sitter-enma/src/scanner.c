#include "tree_sitter/parser.h"
#include <stdbool.h>
#include <string.h>
#include <wctype.h>

enum TokenType {
    COMMENT,
    PREPROCESSOR_DIRECTIVE,
    INTERPOLATION_OPEN,
    INTERPOLATION_CLOSE,
};

typedef struct {
    int8_t interpolation_depth;
} Scanner;

static inline void advance(TSLexer *lexer) { lexer->advance(lexer, false); }
static inline void skip(TSLexer *lexer) { lexer->advance(lexer, true); }

// Block comment: /* ... */ with nesting
static bool scan_block_comment(TSLexer *lexer) {
    // We've already consumed '/' — now at '*'
    advance(lexer); // consume '*'
    unsigned depth = 1;
    int32_t prev = '*';
    while (lexer->lookahead != 0 && depth > 0) {
        if (prev == '*' && lexer->lookahead == '/') {
            advance(lexer); // consume '/'
            depth--;
            prev = '/';
        } else if (prev == '/' && lexer->lookahead == '*') {
            advance(lexer); // consume '*'
            depth++;
            prev = '*';
        } else {
            prev = (int32_t)lexer->lookahead;
            advance(lexer);
        }
    }
    lexer->result_symbol = COMMENT;
    return true;
}

// Handle comments
static bool scan_comment(TSLexer *lexer) {
    if (lexer->lookahead != '/') return false;
    advance(lexer); // consume first '/'

    // Line comment: //
    if (lexer->lookahead == '/') {
        advance(lexer);
        while (lexer->lookahead != 0 && lexer->lookahead != '\n') {
            advance(lexer);
        }
        lexer->result_symbol = COMMENT;
        return true;
    }

    // Block comment: /* ... */
    if (lexer->lookahead == '*') {
        return scan_block_comment(lexer);
    }

    return false;
}

// Preprocessor directive at column 0
static bool scan_preprocessor(TSLexer *lexer) {
    if (lexer->lookahead != '#') return false;
    if (lexer->get_column(lexer) != 0) return false;

    advance(lexer); // consume '#'
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
        advance(lexer);
    }
    while (iswalpha(lexer->lookahead) || lexer->lookahead == '_') {
        advance(lexer);
    }
    while (lexer->lookahead != 0 && lexer->lookahead != '\n') {
        advance(lexer);
    }

    lexer->result_symbol = PREPROCESSOR_DIRECTIVE;
    return true;
}

// f-string interpolation tracking
static bool scan_interpolation(TSLexer *lexer, Scanner *scanner, bool open) {
    if (scanner->interpolation_depth <= 0) return false;

    if (open) {
        if (lexer->lookahead != '{') return false;
        // Escaped {{ — consume both, don't emit token
        advance(lexer);
        if (lexer->lookahead == '{') {
            advance(lexer);
            return false;
        }
        scanner->interpolation_depth++;
        lexer->result_symbol = INTERPOLATION_OPEN;
        return true;
    } else {
        if (lexer->lookahead != '}') return false;
        advance(lexer);
        // Escaped }}
        if (lexer->lookahead == '}') {
            advance(lexer);
            return false;
        }
        scanner->interpolation_depth--;
        lexer->result_symbol = INTERPOLATION_CLOSE;
        return true;
    }
}

// Scanner lifecycle
void *tree_sitter_enma_external_scanner_create(void) {
    Scanner *scanner = calloc(1, sizeof(Scanner));
    return scanner;
}

void tree_sitter_enma_external_scanner_destroy(void *payload) {
    free(payload);
}

unsigned tree_sitter_enma_external_scanner_serialize(void *payload, char *buffer) {
    Scanner *scanner = (Scanner *)payload;
    buffer[0] = (char)scanner->interpolation_depth;
    return 1;
}

void tree_sitter_enma_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
    Scanner *scanner = (Scanner *)payload;
    if (length >= 1) scanner->interpolation_depth = (int8_t)buffer[0];
}

// Main scan entry
bool tree_sitter_enma_external_scanner_scan(
    void *payload,
    TSLexer *lexer,
    const bool *valid_symbols
) {
    Scanner *scanner = (Scanner *)payload;

    // Interpolation tokens (inside f-string)
    if (valid_symbols[INTERPOLATION_OPEN] && scanner->interpolation_depth > 0) {
        if (scan_interpolation(lexer, scanner, true)) return true;
    }
    if (valid_symbols[INTERPOLATION_CLOSE] && scanner->interpolation_depth > 1) {
        if (scan_interpolation(lexer, scanner, false)) return true;
    }

    // Skip whitespace
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
           lexer->lookahead == '\r' || lexer->lookahead == '\f') {
        skip(lexer);
    }

    // Comments
    if (valid_symbols[COMMENT] && scan_comment(lexer)) {
        return true;
    }

    // Preprocessor (column 0 only)
    if (valid_symbols[PREPROCESSOR_DIRECTIVE] && scan_preprocessor(lexer)) {
        return true;
    }

    return false;
}
