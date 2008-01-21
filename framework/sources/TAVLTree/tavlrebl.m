/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLREBL.C    V.9;  20-Oct-91,13:38:42"
 *
 *  Module:  Rebalance
 *  Purpose: Rebalance the TAVLtree "a", which is unbalanced by at most
 *           one leaf.  This function may be called by either "tavl_insert"
 *           or "tavl_delete"; Rebalance is considered to be private to the
 *           TAVL routines, its prototype is in the header "tavlpriv.h",
 *           whereas user routine prototypes are in "tavltree.h".
 *           Assumes balance factors & threads are correct; Returns pointer
 *           to root of balanced tree; threads & balance factors have been
 *           corrected if necessary.  If the height of the subtree "a"
 *           decreases by one, tavl_rebalance sets *deltaht to 1, otherwise
 *           *deltaht is set to 0.  If "tavl_rebalance" is called by
 *           "tavl_insert", *deltaht will always be set to 1 - just by the
 *           nature of the algorithm.  So the function "tavl_insert" does
 *           not need the information provided by *deltaht;  however,
 *           "tavl_delete" does use this information.
 *
 *  Author:  Bert C. Hughes
 *
 * !!NOTE!!  This module must be linked into any program which uses
 *           the TAVL library functions "tavl_insert" or "tavl_delete"!
 *           This module is strictly for the use of those functions, and
 *           is NOT intended to be a "user", or TAVL library, function.
 *
 *  Released to the PUBLIC DOMAIN
 *                          Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

   /* Debugging "assert"s are in the code to test integrity of the    */
   /* tree. All assertions should be removed from production versions */
   /* of the library by compiling the library with NDEBUG defined.    */
   /* See the header "assert.h".*/

#include <stdlib.h>
#include <assert.h>
#include "tavltree.h"
#include "tavlpriv.h"

TAVL_nodeptr rebalance_tavl(TAVL_nodeptr a, char *deltaht)
{
    TAVL_nodeptr b,c,sub_root = NULL;   /* sub_root will be the return value, */
                                 /* and the root of the newly rebalanced*/
                                 /* sub-tree */

                    /*  definition(tree-height(X)) : the maximum    */
                    /*      path length from node X to a leaf node. */
    *deltaht = 0;   /*  *deltaht is set to 1 if and only if         */
                    /*      tree-height(rebalance()) < tree-height(a)*/

    if (Is_Head(a)          /* Never rebalance the head node! */
        || abs(a->bf) <= 1) /* tree "a" is balanced - nothing more to do */
        return(a);

    if (a->bf == LEFT+LEFT) {
        b = a->Lptr;
        if (b->bf != RIGHT) {   /* LL rotation */
            if (RTHREAD(b)) {       /* b->Rptr is a thread to "a" */
                assert(b->Rptr == a);
                a->Lbit = THREAD;   /* change from link to thread */
                b->Rbit = LINK;     /* change thread to link */
            }
            else {
                a->Lptr = b->Rptr;
                b->Rptr = a;
            }

            *deltaht = b->bf ? 1 : 0;
            a->bf = - (b->bf += RIGHT);

            sub_root = b;
        }
        else {                  /* LR rotation */
            *deltaht = 1;

            c = b->Rptr;
            if (LTHREAD(c)) {
                assert(c->Lptr == b);
                c->Lbit = LINK;
                b->Rbit = THREAD;
            }
            else {
                b->Rptr = c->Lptr;
                c->Lptr = b;
            }

            if (RTHREAD(c)) {
                assert(c->Rptr == a);
                c->Rbit = LINK;
                a->Lptr = c;
                a->Lbit = THREAD;
            }
            else {
                a->Lptr = c->Rptr;
                c->Rptr = a;
            }

            switch (c->bf) {
                case LEFT:  b->bf = 0;
                            a->bf = RIGHT;
                            break;

                case RIGHT: b->bf = LEFT;
                            a->bf = 0;
                            break;

                case 0:     b->bf = 0;
                            a->bf = 0;
            }

            c->bf = 0;

            sub_root = c;
        }
    }
    else if (a->bf == RIGHT+RIGHT) {
        b = a->Rptr;
        if (b->bf != LEFT) {    /* RR rotation */
            if (LTHREAD(b)) {       /* b->Lptr is a thread to "a" */
                assert(b->Lptr == a);
                a->Rbit = THREAD;   /* change from link to thread */
                b->Lbit = LINK;     /* change thread to link */
            }
            else {
                a->Rptr = b->Lptr;
                b->Lptr = a;
            }
            *deltaht = b->bf ? 1 : 0;
            a->bf = - (b->bf += LEFT);

            sub_root = b;
        }
        else {                  /* RL rotation */
            *deltaht = 1;

            c = b->Lptr;
            if (RTHREAD(c)) {
                assert(c->Rptr == b);
                c->Rbit = LINK;
                b->Lbit = THREAD;
            }
            else {
                b->Lptr = c->Rptr;
                c->Rptr = b;
            }

            if (LTHREAD(c)) {
                assert(c->Lptr == a);
                c->Lbit = LINK;
                a->Rptr = c;
                a->Rbit = THREAD;
            }
            else {
                a->Rptr = c->Lptr;
                c->Lptr = a;
            }

            switch (c->bf) {
                case RIGHT: b->bf = 0;
                            a->bf = LEFT;
                            break;

                case LEFT:  b->bf = RIGHT;
                            a->bf = 0;
                            break;

                case 0:     b->bf = 0;
                            a->bf = 0;
            }

            c->bf = 0;

            sub_root = c;
        }
    }

    return sub_root;

}/* end rebalance */
