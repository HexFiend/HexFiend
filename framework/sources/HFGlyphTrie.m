#import "HFGlyphTrie.h"
#import <objc/objc-auto.h>

/* If branchingDepth is 1, then this is a leaf and there's nothing to free (a parent frees its children).  If branchingDepth is 2, then this is a branch whose children are leaves, so we have to free the leaves but we do not recurse.  If branchingDepth is greater than 2, we do have to recurse. */
static void freeTrie(struct HFGlyphTrieBranch_t *branch, uint8_t branchingDepth) {
    HFASSERT(branchingDepth >= 1);
    NSUInteger i;
    if (branchingDepth > 2) {
        /* Recurse */
        for (i=0; i < kHFGlyphTrieBranchCount; i++) {
            if (branch->children[i]) {
                freeTrie(branch->children[i], branchingDepth - 1);
            }
        }
    }
    if (branchingDepth > 1) {
        /* Free our children */
        for (i=0; i < kHFGlyphTrieBranchCount; i++) {
            free(branch->children[i]);
        }
    }
}

static void insertTrie(void *node, uint8_t branchingDepth, NSUInteger key, struct HFGlyph_t value) {
    HFASSERT(node != NULL);
    HFASSERT(branchingDepth >= 1);
    if (branchingDepth == 1) {
        /* Leaf */
        HFASSERT(key < kHFGlyphTrieBranchCount);
        ((struct HFGlyphTrieLeaf_t *)node)->glyphs[key] = value;
    } else {
        /* Branch */
        struct HFGlyphTrieBranch_t *branch = node;
        NSUInteger keySlice = key & ((1 << kHFGlyphTrieBranchFactor) - 1), keyRemainder = key >> kHFGlyphTrieBranchFactor;
        __strong void *child = branch->children[keySlice];
        if (child == NULL) {
            if (branchingDepth == 2) {
                child = calloc(1, sizeof(struct HFGlyphTrieLeaf_t));
            } else {
                child = calloc(1, sizeof(struct HFGlyphTrieBranch_t));
            }
            /* We just zeroed out a block of memory and we are about to write its address somewhere where another thread could read it, so we need a memory barrier. */
            OSMemoryBarrier();
            branch->children[keySlice] = child;
        }
        insertTrie(child, branchingDepth - 1, keyRemainder, value);
    }    
}

static struct HFGlyph_t getTrie(const void *node, uint8_t branchingDepth, NSUInteger key) {
    HFASSERT(node != NULL);
    HFASSERT(branchingDepth >= 1);
    if (branchingDepth == 1) {
        /* Leaf */
        HFASSERT(key < kHFGlyphTrieBranchCount);
        return ((const struct HFGlyphTrieLeaf_t *)node)->glyphs[key];
    } else {
        /* Branch */
        const struct HFGlyphTrieBranch_t *branch = node;
        NSUInteger keySlice = key & ((1 << kHFGlyphTrieBranchFactor) - 1), keyRemainder = key >> kHFGlyphTrieBranchFactor;
        if (branch->children[keySlice] == NULL) {
            /* Not found */
            return (struct HFGlyph_t){0, 0};
        } else {
            /* This dereference requires a data dependency barrier */
            return getTrie(branch->children[keySlice], branchingDepth - 1, keyRemainder);
        }
    }
}

void HFGlyphTrieInsert(struct HFGlyphTrie_t *trie, NSUInteger key, struct HFGlyph_t value) {
    insertTrie(&trie->root, trie->branchingDepth, key, value);
}

struct HFGlyph_t HFGlyphTrieGet(const struct HFGlyphTrie_t *trie, NSUInteger key) {
    struct HFGlyph_t result = getTrie(&trie->root, trie->branchingDepth, key);
    return result;
}

void HFGlyphTrieInitialize(struct HFGlyphTrie_t *trie, uint8_t keySize) {
    /* If the branch factor is 4 (bits) and the key size is 2 bytes = 16 bits, initialize branching depth to 16/4 = 4 */
    uint8_t keyBits = keySize * CHAR_BIT;
    HFASSERT(keyBits % kHFGlyphTrieBranchFactor == 0);
    trie->branchingDepth = keyBits / kHFGlyphTrieBranchFactor;
    memset(&trie->root, 0, sizeof(trie->root));
}

void HFGlyphTreeFree(struct HFGlyphTrie_t * trie) {
    /* Don't try to free under GC.  And don't free if it's never been initialized. */
    if (trie->branchingDepth > 0) {
        freeTrie(&trie->root, trie->branchingDepth);
    }
}
