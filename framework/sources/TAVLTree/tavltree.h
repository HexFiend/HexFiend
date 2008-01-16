#if !defined TAVLtree_H
#define TAVLtree_H

/*:file:version:date: "%n    V.%v;  %f"
 * "TAVLTREE.H    V.20;  20-Oct-91,13:38:38"
 *
 *  Threaded-AVL, or threaded height-balanced trees
 *
 *  Purpose:    Threaded AVL trees provide fast access ,O(log N),
 *              to data nodes AND allow efficient ,O(1), sequential
 *              access; i.e., given a node, the next or previous
 *              node can be efficiently accessed.
 *
 *  References: Fundamentals of Data Structures; Horowitz & Sahni
 *              Computer Science Press
 *              See 5.6 (threaded trees) & 9.2 (dynamic tree tables)
 *
 *  Released to the PUBLIC DOMAIN
 *
 *  Author:             Bert C. Hughes
 *                      200 N. Saratoga
 *                      St.Paul, MN 55104
 *                      Compuserve 71211,577
 */

/* Constants for "replace" parameter of "tavl_insert" */
#define REPLACE     1
#define NO_REPLACE  0

/*  Constants are possible return values of "tavl_setdata" */
#define TAVL_OK          0  /* No error. */
#define TAVL_NOMEM       1  /* Out of memory error */
#define TAVL_ILLEGAL_OP  2  /* Requested operation would disrupt the
                               tavl_tree structure; operation cancelled! */

#include <stddef.h>         /* for definition of "NULL" */

typedef struct tavlnode *TAVL_nodeptr;
typedef struct tavltree *TAVL_treeptr;

/* prototypes */

__private_extern__ TAVL_treeptr tavl_init(int (*compare)(void *key1, void *key2),
                    void *(*key_of)(void *DataObject),
                    void *(*make_item)(const void *DataObject),
                    void (*free_item)(void *DataObject),
                    void *(*copy_item)(void *Destination_DataObject,\
                                 const void *Source_DataObject),
                    void *(*alloc)(size_t),
                    void (*dealloc)(void *)
                    );
            /*
            Returns pointer to empty tree on success, NULL if insufficient
            memory.  The function pointers passed to "tavl_init" determine
            how that instance of tavl_tree will behave & how it will use
            dynamic memory.

                parameters-
                  compare:      Compares identifiers, same form as "strcmp".
                  key_of:       Gets pointer to a data object's identifier.
                  make_item:    Creates new data object that is a copy of
                                *DataObject.
                  free_item:    Complements make_item. Releases any memory
                                allocated to DataObject by "make_item".
                  copy_item:    Copies data object *Source to buffer *Dest
                  alloc:        Memory allocator.
                  dealloc:      Deallocates dynamic memory - complements
                                "alloc"
            */


__private_extern__ int tavl_setdata(TAVL_treeptr tree, TAVL_nodeptr p, void *item);
            /*
            Replace data contents of *p with *item.
            returns:
                0  ................ OK
                TAVL_NOMEM ........ out of memory (heap space)
                TAVL_ILLEGAL_OP ...
                     (*tree->key_of)(p->dataptr) != (*tree->key_of)(item)

            Uses "make_item" and "free_item". See tavl_init.
            */

__private_extern__ void *tavl_getdata(TAVL_treeptr tree, TAVL_nodeptr p, void *buffer);
            /*
            A safe method of reading the data contained in TAVL_NODE.
            If user/programmer uses "dataptr" for anything other than
            reading the data "dataptr" points to, the tavl_tree will
            be corrupted.  Returns *buffer;  Data will be copied to
            buffer using method "copy_item"; see tavl_init.
            */

__private_extern__ TAVL_nodeptr tavl_insert(TAVL_treeptr tree, void *item, int replace);
            /*
            Using the user supplied "key_of" & "compare" functions,
            *tree is searched for a node which matches *item. If a
            match is found, the new item replaces the old if & only
            if replace != 0.  If no match is found the item is
            inserted into *tree.  "tavl_insert" returns a pointer to
            the node inserted or found, or NULL if there is not enough
            memory to create a new node and copy "item".  Uses functions
            "key_of" and "compare" for comparisons and to retrieve
            identifiers from data objects, "make_item" to create a copy
            of "item", "alloc" to get memory for the new tree node, and
            "dealloc" if "make_item" fails.
            */

__private_extern__ int tavl_delete(TAVL_treeptr tree, void *key);
            /*
            Delete node identified by "key" from *tree.
            Returns 1 if found and deleted, 0 if not found.
            Uses "compare", "key_of", "free_item" and "dealloc".
            See function tavl_init.
            */

__private_extern__ void tavl_delete_all(TAVL_treeptr tree);
            /*
            Remove all data nodes from tree, release memory used.
            */

__private_extern__ void tavl_destroy(TAVL_treeptr tree);
            /*
            Destroy the tree. Uses functions "free_item" and "dealloc"
            to restore pool memory used. See function tavl_init.
            */

__private_extern__ TAVL_nodeptr tavl_find(TAVL_treeptr tree, void *key);
            /*
            Returns pointer to node which contains data item
            in *tree whose identifier equals "key". Uses "key_of"
            to retrieve identifier of data items in the tree,
            "compare" to compare the identifier retrieved with
            *key.  Returns NULL if *key is not found.
            */

/********************************************************************
    Following three functions allow you to treat tavl_trees as a
    doubly linked sorted list with a head node.  This is the point
    of threaded trees - it is almost as efficient to move from node
    to node or back with a threaded tree as it is with a linked list.
*********************************************************************/

__private_extern__ TAVL_nodeptr tavl_reset(TAVL_treeptr tree);
            /*
            Returns pointer to begin/end of *tree (the head node).
            A subsequent call to tavl_succ will return a pointer
            to the node containing first (least) item in the tree;
            just as a call to tavl_pred would return the last
            (greatest).  Pointer returned can only be used a parameter
            to "tavl_succ" or "tavl_pred" - the head node contains no
            user data.
            */

__private_extern__ TAVL_nodeptr tavl_succ(TAVL_nodeptr p);
            /*
            Returns successor of "p", or NULL if "p" has no successor.
            */

__private_extern__ TAVL_nodeptr tavl_pred(TAVL_nodeptr p);
            /*
            Returns predecessor of "p", or NULL if no predecessor.
            */

/**************      END PUBLIC DEFINITIONS     *******************/

/* Private: for internal use by tavl*.c library routines only! */

/*   See note below
     ... recommended that TAVL_USE_BIT_FIELDS remain commented out,
     ... both for efficiency (speed) and universiality.
#define TAVL_USE_BIT_FIELDS
*/

typedef struct tavlnode {
            __strong void *dataptr;
            struct tavlnode *Lptr, *Rptr;
#if !defined TAVL_USE_BIT_FIELDS
                                        /* see NOTE below */
            signed  char bf;            /* assumes values -2..+2 */
                    char Lbit;          /* 0 or 1 */
                    char Rbit;          /* 0 or 1 */
#else
            signed   int bf     : 3;    /* assumes values -2..+2 */
            unsigned int Lbit   : 1;
            unsigned int Rbit   : 1;
#endif
        } TAVL_NODE;

typedef struct tavltree {
            TAVL_nodeptr head;
            int (*cmp)(void *, void *);
            void *(*key_of)(void *);
            void *(*make_item)(const void *);
            void (*free_item)(void *);
            void *(*copy_item)(void *, const void *);
            void *(*alloc)(size_t);
            void (*dealloc)(void *);
        } TAVL_TREE;

/* end private */

/* !!! NOTE */
   /*
    * R.Artigas points out that some Standard C compilers do NOT support
    * signed bit fields; in particular, Microsoft C version 5.1 does not.
    *
    * It may also be true that bit field testing is not so efficient
    * as using "char"s for flag variables - it depends on the compiler.
    *
    * By default, TAVLTREE uses char variables for flags in TAVL_NODE.
    * If you wish to use bit fields instead, define "TAVL_USE_BIT_FIELDS".
    */

#endif
