#if !defined TAVLPRIV_H
#define TAVLPRIV_H

/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLPRIV.H    V.8;  1-Oct-91,20:16:32"
 *
 *  module: TAVLPRIV.H
 *  author: Bert C. Hughes
 *  purpose: Internal stuff for TAVLtree library functions.
 *           None of the definitions or prototypes in this header
 *           are for "public" use - this header is for the private
 *           use of the TAVL library only. This header must be present
 *           when the TAVL library functions are compiled, but "tavlpriv.h"
 *           never needs to be included in any application.
 *
 *  Released to the PUBLIC DOMAIN
 *
 *                      Bert C. Hughes
 *                      200 N. Saratoga
 *                      St.Paul, MN 55104
 *                      Compuserve 71211,577
 *
 */

#include "tavltree.h"     /* for typedef of "TAVL_nodeptr" & "NULL" */

#define RIGHT   -1
#define LEFT    +1
#define THREAD  0
#define LINK    1
#define LLINK(x)    ((x)->Lbit)
#define RLINK(x)    ((x)->Rbit)
#define LTHREAD(x)  (!LLINK(x))
#define RTHREAD(x)  (!RLINK(x))
#define Leftchild(x)    (LLINK(x) ? (x)->Lptr : NULL)
#define Rightchild(x)   (RLINK(x) ? (x)->Rptr : NULL)
#define Is_Head(x)      ((x)->Rptr == (x))
                            /* always true for head node of initialized */
                            /* tavl_tree, and false for all other nodes */

#define RECUR_STACK_SIZE 40  /* this is extremely enormous */

__private_extern__ TAVL_nodeptr rebalance_tavl(TAVL_nodeptr a, char *deltaht);
/*  Returns pointer to root of rebalanced tree "a".  If rebalance reduces
    the height of tree "a", *deltaht = 1, otherwise *deltaht = 0.
    "rebalance_tavl" is called ONLY by "tavl_insert" and "tavl_delete".
    *deltaht is always 1 when "rebalance_tavl" is called by "tavl_insert";
    however, *deltaht may return 1 or 0 when called by "tavl_delete".
*/

#endif
