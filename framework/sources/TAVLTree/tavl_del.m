/*:file:version:date: "%n    V.%v;  %f"
 * "TAVL_DEL.C    V.11;  19-Oct-91,14:47:10"
 *
 *      Module:     tavl_delete
 *      Purpose:    Delete from TAVL tree the node whose identifier
 *                  equals "*identifier", if such a node exists. Returns
 *                  non-zero if & only if a node is deleted.
 *
 * !!NOTE!!     Programs that use this module must also link in the module
 *              whose source is in the file "TAVLREBL.C".
 *
 *  Released to the PUBLIC DOMAIN
 *
 *               author:    Bert C. Hughes
 *                          200 N.Saratoga
 *                          St.Paul, MN 55104
 *                          Compuserve 71211,577
 */

   /* Debugging "assert"s are in the code to test integrity of the    */
   /* tree. All assertions should be removed from production versions */
   /* of the library by compiling the library with NDEBUG defined.    */
   /* See the header "assert.h".*/

#include <assert.h>
#include "tavltree.h"
#include "tavlpriv.h"

static TAVL_nodeptr remove_node(TAVL_treeptr tree, TAVL_nodeptr p, char *deltaht);
static TAVL_nodeptr remove_max(TAVL_nodeptr p, TAVL_nodeptr *maxnode, char *deltaht);
static TAVL_nodeptr remove_min(TAVL_nodeptr p, TAVL_nodeptr *minnode, char *deltaht);

/*  Development note:  the routines "remove_min" and "remove_max" are
    true recursive routines; i.e., they make calls to themselves. The
    routine "tavl_delete" simulates recursion using a stack (a very deep
    one that should handle any imaginable tree size - up to approximately
    1 million squared nodes).  I arrived at this particular mix by using
    Borland's Turbo Profiler and a list of 60K words as a test file to
    example1.c, which should be included in the distribution package.
    -BCH
*/


int tavl_delete (TAVL_treeptr tree, void *key)
{
    char rb, deltaht;
    int side;
    int  found = deltaht = 0;
    register TAVL_nodeptr p = Leftchild(tree->head);
    register int cmpval = -1;
    register TAVL_nodeptr q=NULL;

    struct stk_item {
            int side;
            TAVL_nodeptr p;
        } block[RECUR_STACK_SIZE];

    struct stk_item *next = block;   /* initialize recursion stack */

#define PUSH_PATH(x,y)  (next->p = (x),  (next++)->side = (y))
#define POP_PATH(x)     (x = (--next)->side, (next->p))

    tree->head->bf = 0;      /* prevent tree->head from being rebalanced */

    PUSH_PATH(tree->head,LEFT);

    while (p) {
        cmpval = (*tree->cmp)(key,(*tree->key_of)(p->dataptr));
        if (cmpval > 0) {
            PUSH_PATH(p,RIGHT);
            p = Rightchild(p);
        }
        else if (cmpval < 0) {
            PUSH_PATH(p,LEFT);
            p = Leftchild(p);
        }
        else /* cmpval == 0 */ {
            q = p;
            p = NULL;
            found = 1;
        }
    } /* end while(p) */

    if (!found) return 0;

    (*tree->free_item)(q->dataptr);
    q = remove_node(tree,q,&deltaht);

    do {
        p = POP_PATH(side);

        if (side != RIGHT)
            p->Lptr = q;
        else
            p->Rptr = q;

        q = p;  rb = 0;

        if (deltaht) {
            p->bf -= side;
            switch (p->bf) {
                case 0:     break;  /* longest side shrank to equal shortest */
                                    /* therefor deltaht remains true */
                case LEFT:
                case RIGHT: deltaht = 0;/* other side is deeper */
                            break;

                default:    {
                                q = rebalance_tavl(p,&deltaht);
                                rb = 1;
                            }
            }
        }
    } while ((p != tree->head) && (rb || deltaht));

    return 1;

#undef PUSH_PATH
#undef POP_PATH

} /* tavl_delete */


static TAVL_nodeptr remove_node(TAVL_treeptr tree, TAVL_nodeptr p, char *deltaht)
{
    char dh;
    TAVL_nodeptr q;

    *deltaht = 0;

    if (p->bf != LEFT) {
        if (RLINK(p)) {
            p->Rptr = remove_min(p->Rptr,&q,&dh);
            if (dh) {
                p->bf += LEFT;  /* becomes 0 or LEFT */
                *deltaht = (p->bf) ? 0 : 1;
            }
        }
        else { /* leftchild(p),rightchild(p) == NULL */
            assert(p->bf == 0);
            assert(LTHREAD(p));

            *deltaht = 1;           /* p will be removed, so height changes */
            if (p->Rptr->Lptr == p) { /* p is leftchild of it's parent */
                p->Rptr->Lbit = THREAD;
                q = p->Lptr;
            }
            else {  /* p is rightchild of it's parent */
                assert(p->Lptr->Rptr == p);
                p->Lptr->Rbit = THREAD;
                q = p->Rptr;
            }
            (*tree->dealloc)(p);
            return q;
        }
    }
    else { /* p->bf == LEFT */
        p->Lptr = remove_max((p->Lptr),&q,&dh);
        if (dh) {
            p->bf += RIGHT;      /* becomes 0 or RIGHT */
            *deltaht = (p->bf) ? 0 : 1;
        }
    }

    p->dataptr = q->dataptr;
    (*tree->dealloc)(q);
    return p;
}

static TAVL_nodeptr remove_min(TAVL_nodeptr p, TAVL_nodeptr *minnode, char *deltaht)
{
    char dh = *deltaht = 0;

    if (LLINK(p)) { /* p is not minimum node */
        p->Lptr = remove_min(p->Lptr,minnode,&dh);
        if (dh) {
            p->bf += RIGHT;
            switch (p->bf) {
                case 0: *deltaht = 1;
                        break;
                case RIGHT+RIGHT:
                        p = rebalance_tavl(p,deltaht);
            }
        }
        return p;
    }
    else { /* p is minimum */
        *minnode = p;
        *deltaht = 1;
        if (RLINK(p)) {
            assert(p->Rptr->Lptr == p);
            assert(LTHREAD(p->Rptr) && RTHREAD(p->Rptr));

            p->Rptr->Lptr = p->Lptr;
            return p->Rptr;
        }
        else
            if (p->Rptr->Lptr != p) {   /* was first call to remove_min, */
                p->Lptr->Rbit = THREAD; /* from "remove", not remove_min */
                return p->Rptr;         /* p is never rightchild of head */
            }
            else {
                p->Rptr->Lbit = THREAD;
                return p->Lptr;
            }
    }
}

static TAVL_nodeptr remove_max(TAVL_nodeptr p, TAVL_nodeptr *maxnode, char *deltaht)
{
    char dh = *deltaht = 0;

    if (RLINK(p)) { /* p is not maximum node */
        p->Rptr = remove_max(p->Rptr,maxnode,&dh);
        if (dh) {
            p->bf += LEFT;
            switch (p->bf) {
                case 0: *deltaht = 1;
                        break;
                case LEFT+LEFT:
                        p = rebalance_tavl(p,deltaht);
            }
        }
        return p;
    }
    else { /* p is maximum */
        *maxnode = p;
        *deltaht = 1;
        if (LLINK(p)) {
            assert(LTHREAD(p->Lptr) && RTHREAD(p->Lptr));
            assert(p->Lptr->Rptr == p);

            p->Lptr->Rptr = p->Rptr;
            return p->Lptr;
        }
        else
            if (p->Rptr->Lptr == p) {   /* p is leftchild of its parent */
                p->Rptr->Lbit = THREAD; /* test must use p->Rptr->Lptr */
                return p->Lptr;         /* because p may be predecessor */
            }                           /* of head node */
            else {
                p->Lptr->Rbit = THREAD;  /* p is rightchild of its parent */
                return p->Rptr;
            }
    }
}
