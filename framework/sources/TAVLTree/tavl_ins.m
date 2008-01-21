/*:file:version:date: "%n    V.%v;  %f"
 * "TAVL_INS.C    V.12;  19-Oct-91,14:19:36"
 *
 *  Module:     tavl_insert
 *  Purpose:    Insert item into TAVL_TREE;  "item" may be anything,
 *              but the user-defined function "key_of()" given when tree was
 *              initialized by "tavl_init()" must be able to read an
 *              identifier from "item" which can be compared with other
 *              indentifiers via the user defined function "cmp()".
 *
 *              If a datanode is found such that identifier(datanode) equals
 *              identifier(item), the new data from item replaces the data
 *              existing in datanode if & only if parameter replace == 1.
 *
 * !!NOTE!!     Programs that use this module must also link in the module
 *              whose source is in the file "TAVLREBL.C".
 *
 *
 *  Released to the PUBLIC DOMAIN
 *
 *  author:                 Bert C. Hughes
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
#include <stdlib.h>

TAVL_nodeptr tavl_insert(TAVL_treeptr tree, void *item, int replace)
                /*
                Using the user supplied (key_of) & (cmp) functions, *tree
                is searched for a node which matches *item. If a match is
                found, the new item replaces the old if & only if
                replace != 0.  If no match is found the item is inserted
                into *tree.  "tavl_insert" returns a pointer to the node
                inserted into or found in *tree. "tavl_insert" returns
                NULL if & only if it is unable to allocate memory for
                a new node.
                */
{
    TAVL_nodeptr a,y,f;
    register TAVL_nodeptr p,q;
    register int cmpval = -1; /* cmpval must be initialized - if tree is */
    int side;                 /* empty node inserted as LeftChild of head */
    char junk;

    /*  Locate insertion point for item.  "a" keeps track of most
        recently seen node with (bf != 0) - or it is the top of the
        tree, if no nodes with (p->bf != 0) are encountered.  "f"
        is parent of "a".  "q" follows "p" through tree.
    */

    q = tree->head;   a = q;  f = NULL;  p = Leftchild(q);

    while (p) {
        if (p->bf) { a = p; f = q; }

        q = p;

        cmpval = (*tree->cmp)((*tree->key_of)(item),(*tree->key_of)(p->dataptr));

        if (cmpval < 0)
            p = Leftchild(p);
        else if (cmpval > 0)
            p = Rightchild(p);
        else {
            if (replace) {
                void *temp = (*tree->make_item)(item);
                if (temp) {
                    (*tree->free_item)(p->dataptr);
                    p->dataptr = temp;
                }
                else p = NULL;
            }
            return p;
        }
    }

    /* wasn't found - create new node as child of q */

    y = (*tree->alloc)(sizeof(TAVL_NODE));

    if (y) {
        y->bf = 0;
        y->Lbit = THREAD;
        y->Rbit = THREAD;
        if ((y->dataptr = (*tree->make_item)(item)) == NULL) {
            (*tree->dealloc)(y);
            return NULL;        /* must be out of memory */
        }
    }
    else return NULL;           /* out of memory */

    if (cmpval < 0) {           /* connect to tree and thread it */
        y->Lptr = q->Lptr;
        y->Rptr = q;
        q->Lbit = LINK;
        q->Lptr = y;
    }
    else {
        y->Rptr = q->Rptr;
        y->Lptr = q;
        q->Rbit = LINK;
        q->Rptr = y;
    }

    /*  Adjust balance factors on path from a to q.  By definition of "a",
        all nodes on this path have bf = 0, and so will change to LEFT or
        RIGHT.
    */

    if ((a == tree->head) || ((*tree->cmp)((*tree->key_of)(item),
                                           (*tree->key_of)(a->dataptr))< 0)) {
        p = a->Lptr; side = LEFT;
    }
    else {
        p = a->Rptr; side = RIGHT;
    }

    /* adjust balance factors */

    while (p != y) {
        if ((*tree->cmp)((*tree->key_of)(p->dataptr),(*tree->key_of)(item))> 0) {
            p->bf = LEFT;   p = p->Lptr;
        }
        else {
            p->bf = RIGHT;  p = p->Rptr;
        }
    }

    tree->head->bf = 0;     /* if a==tree->head, tree is already balanced */

    /* Is tree balanced? */

    if (abs(a->bf += side) < 2) return y;

    p = rebalance_tavl(a,&junk);

    assert(junk);   /* rebalance always sets junk to 0 */

    assert(f);      /* f was set non-NULL by the search loop */

    if (f->Rptr != a)
        f->Lptr = p;
    else
        f->Rptr = p;

    return y;
}
