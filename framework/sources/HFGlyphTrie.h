#import <HexFiend/HFFrameworkPrefix.h>

/* HFGlyphTrie is used to represent a trie of glyphs that allows multiple concurrent readers, along with one writer. */


NS_ASSUME_NONNULL_BEGIN

/* BranchFactor is in bits */
#define kHFGlyphTrieBranchFactor 4
#define kHFGlyphTrieBranchCount (1 << kHFGlyphTrieBranchFactor)

typedef uint16_t HFGlyphFontIndex;
#define kHFGlyphFontIndexInvalid ((HFGlyphFontIndex)(-1))

#define kHFGlyphInvalid kCGFontIndexInvalid

struct HFGlyph_t {
    HFGlyphFontIndex fontIndex;
    CGGlyph glyph;
};

static inline BOOL HFGlyphEqualsGlyph(struct HFGlyph_t a, struct HFGlyph_t b) __attribute__((unused));
static inline BOOL HFGlyphEqualsGlyph(struct HFGlyph_t a, struct HFGlyph_t b) {
    return a.glyph == b.glyph && a.fontIndex == b.fontIndex;
}

struct HFGlyphTrieBranch_t {
    void *_Nullable children[kHFGlyphTrieBranchCount];
};

struct HFGlyphTrieLeaf_t {
    struct HFGlyph_t glyphs[kHFGlyphTrieBranchCount];
};

struct HFGlyphTrie_t {
    uint8_t branchingDepth;
    struct HFGlyphTrieBranch_t root;
};

/* Initializes a trie with a given key size */
__private_extern__ void HFGlyphTrieInitialize(struct HFGlyphTrie_t *trie, uint8_t keySize);

/* Inserts a glyph into the trie */
__private_extern__ void HFGlyphTrieInsert(struct HFGlyphTrie_t *trie, NSUInteger key, struct HFGlyph_t value);

/* Attempts to fetch a glyph.  If the glyph is not present, returns an HFGlyph_t set to all bits 0. */
__private_extern__ struct HFGlyph_t HFGlyphTrieGet(const struct HFGlyphTrie_t *trie, NSUInteger key);

/* Frees all storage associated with a glyph tree.  This is not necessary to call under GC. */
__private_extern__ void HFGlyphTreeFree(struct HFGlyphTrie_t * trie);

NS_ASSUME_NONNULL_END
