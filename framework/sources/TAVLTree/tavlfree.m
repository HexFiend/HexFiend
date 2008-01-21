/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLFREE.C    V.10;  27-Apr-91,12:05:50"
 *
 *  Module : tavl_destroy(TAVL_TREE)
 *  Purpose: Destroy a TAVL tree - free all dynamic memory used.
 *
 *  Released to the PUBLIC DOMAIN
 *
 *              author:     Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"

void tavl_destroy(TAVL_treeptr tree)
{
    register TAVL_nodeptr q;
    register TAVL_nodeptr p = tavl_succ(tavl_reset(tree));

    while (p) {
        p = tavl_succ(q = p);
        (*tree->free_item)(q->dataptr);
        (*tree->dealloc)(q);
    }
    (*tree->dealloc)(tree->head);
    (*tree->dealloc)(tree);
}
