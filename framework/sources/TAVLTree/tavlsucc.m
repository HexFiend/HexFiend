/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLSUCC.C    V.8;  27-Apr-91,12:08:56"
 *
 *  Module : tavl_succ()
 *  Purpose: Return a pointer to the in-order successor of
 *           the node "p"
 *
 *  Released to the PUBLIC DOMAIN
 *
 *             author:      Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"
#include "tavlpriv.h"

TAVL_nodeptr tavl_succ(TAVL_nodeptr p)
{
    register TAVL_nodeptr q;

    if (!p)
        return NULL;

    q = p->Rptr;

    if (RLINK(p))
        while (LLINK(q))
            q = q->Lptr;

    return (Is_Head(q) ? NULL : q);
}
