/*:file:version:date: "%n    V.%v;  %f"
 * "TAVL_RST.C    V.6;  27-Apr-91,12:15:46"
 *
 *  Module:  tavl_reset()
 *  Purpose: Prepare TAVL tree for sequential processing. A TAVL tree
 *           may be viewed as a circular list with a head node, which
 *           contains no data.  "tavl_reset()" returns a pointer to the
 *           tree's head node, which can then be passed to the routines
 *           "tavl_succ" and "tavl_pred".
 *
 *  Released to the PUBLIC DOMAIN
 *
 *  author:                 Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"

TAVL_nodeptr tavl_reset(TAVL_treeptr tree)
{
    return tree->head;
}
