/*:file:version:date: "%n    V.%v;  %f"
 * "TAVL_SDT.C    V.10;  27-Apr-91,12:16:20"
 *
 *  Purpose: Change data in existing node.
 *
 *  Released to the PUBLIC DOMAIN
 *
 *  Author:                 Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"
#include "tavlpriv.h"

int tavl_setdata(TAVL_treeptr tree, TAVL_nodeptr p, void *item)
{
    if (Is_Head(p)) return(TAVL_ILLEGAL_OP);

    if ((*tree->cmp)((*tree->key_of)(p->dataptr),(*tree->key_of)(item)))
        return(TAVL_ILLEGAL_OP);  /* Don't allow identifier to change! */

    (*tree->free_item)(p->dataptr);

    p->dataptr = (*tree->make_item)(item);

    return(p->dataptr ? TAVL_OK : TAVL_NOMEM);
}
