//
//  HFRepresenterStringEncodingTextView.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView.h>
#import <HexFiend/HFGlyphTrie.h>
#import <HexFiend/HFStringEncoding.h>

@interface HFRepresenterStringEncodingTextView : HFRepresenterTextView {
    /* Tier 0 data (always up to date) */
    uint8_t bytesPerChar;
    
    /* Tier 1 data (computed synchronously on-demand) */
    BOOL tier1DataIsStale;
    struct HFGlyph_t replacementGlyph;
    CGFloat glyphAdvancement;

    /* Tier 2 data (computed asynchronously on-demand) */
    struct HFGlyphTrie_t glyphTable;
    
    NSArray *fontCache;
    
    /* Background thread */
    NSLock *glyphLoadLock;
    NSMutableArray *fonts;
    NSMutableIndexSet *requestedCharacters;
    NSOperationQueue *glyphLoader;
}

/// Set and get the HFStringEncoding that is used
@property (nonatomic) HFStringEncoding *encoding;

@end
