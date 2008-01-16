/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLPRED.C    V.8;  27-Apr-91,12:07:34"
 *
 *  Purpose: Return a pointer to the in-order predeccessor of
 *           the node "p"
 *
 *  Released to the PUBLIC DOMAIN
 *
 *              author:     Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"
#include "tavlpriv.h"

TAVL_nodeptr tavl_pred(TAVL_nodeptr p)
{
    register TAVL_nodeptr q;

    if (!p)
        return NULL;

    q = p->Lptr;

    if (LLINK(p))
        while (RLINK(q))
            q = q->Rptr;

    return (Is_Head(q) ? NULL : q);
}
