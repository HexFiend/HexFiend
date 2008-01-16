/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLFIND.C    V.9;  27-Apr-91,12:04:38"
 *
 *  Purpose: Find id:item in tree
 *
 *  Released to the PUBLIC DOMAIN
 *
 *               author:    Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"
#include "tavlpriv.h"

TAVL_nodeptr tavl_find(TAVL_treeptr tree, void *key)
                /* Return pointer to tree node containing data-item
                   identified by "key"; returns NULL if not found */
{
    register TAVL_nodeptr p = Leftchild(tree->head);
    register int side;
    while (p)
    {
        side = (*tree->cmp)(key,(*tree->key_of)(p->dataptr));
        if (side > 0)
            p = Rightchild(p);
        else if (side < 0)
            p = Leftchild(p);
        else
            return p;
    }
    return NULL;
}
