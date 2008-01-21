/*:file:version:date: "%n    V.%v;  %f"
 * "TAVL_GDT.C    V.2;  27-Apr-91,12:10:32"
 *
 *  Purpose: Copy data from existing node to buffer.
 *
 *  Released to the PUBLIC DOMAIN
 *
 *               author:    Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

#include "tavltree.h"

void *tavl_getdata(TAVL_treeptr tree, TAVL_nodeptr p, void *buffer)
{
    return (*tree->copy_item)(buffer, p->dataptr);
}
