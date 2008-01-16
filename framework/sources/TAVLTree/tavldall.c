/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLDALL.C    V.2;  27-Apr-91,12:00:02"
 *
 *  Module : tavl_delete_all(TAVL_TREE)
 *  Purpose: Remove all data nodes, freeing dynamic memory.
 *
 *
 *  Released to PUBLIC DOMAIN
 *
 *                          Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"
#include "tavlpriv.h"

void tavl_delete_all(TAVL_treeptr tree)
{
    register TAVL_nodeptr q;
    register TAVL_nodeptr p = tavl_succ(tavl_reset(tree));

    while (p) {
        p = tavl_succ(q = p);
        (*tree->free_item)(q->dataptr);
        (*tree->dealloc)(q);
    }
    /* fix up the head node */
    tree->head->Lbit = THREAD;
    tree->head->Lptr = tree->head;
}
