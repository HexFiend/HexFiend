extern "C" {
#include "HFHelperProcessSharedCode.h"
#include "FortunateSonServer.h"
#include <unistd.h>

#define MAX_MESSAGE_SIZE 512

static FILE *ERR_FILE;

/* I wish there were a better way to do this */
static void close_all_open_files(void) {
    long open_max = sysconf(_SC_OPEN_MAX);
    int fd;
    for (fd = 0; fd < open_max; fd++) {
	close(fd);
    }
}

static mach_port_t get_parent_receive_port(void) {
    const mach_port_t errorReturn = MACH_PORT_NULL;
    mach_port_t parent_recv_port = MACH_PORT_NULL; //the port on which the parent receives data from us
    mach_port_t child_recv_port = MACH_PORT_NULL; //the poirt on which we receive data to the parent
#if MESS_WITH_BOOTSTRAP_PORT
    CHECK_MACH_ERROR(task_get_bootstrap_port (mach_task_self (), &parent_recv_port));
#else
    // figure out what name our parent used
    char ipc_name[256];
    derive_ipc_name(ipc_name, getppid());
    mach_port_t bp = MACH_PORT_NULL;
    task_get_bootstrap_port(mach_task_self(), &bp);
    CHECK_MACH_ERROR(bootstrap_look_up(bp, ipc_name, &parent_recv_port));
#endif
                     
    // create a port on which we will receive data
    if (setup_recv_port (&child_recv_port) != 0)
	return errorReturn;
    
    if (send_port (parent_recv_port, child_recv_port, MACH_MSG_TYPE_MOVE_SEND) != 0) //Move our send right over.  That way we can get a No Senders notification when Daddy dies, because we can't send to our own port!
	return errorReturn;
    
#if MESS_WITH_BOOTSTRAP_PORT
    if (recv_port (child_recv_port, &bootstrap_port) != 0)
	return errorReturn;
    CHECK_MACH_ERROR(task_set_bootstrap_port (mach_task_self (), bootstrap_port));
#endif
    return child_recv_port;
}

struct DummyMsg_t {
    mach_msg_header_t head;
    mach_msg_body_t body;
    unsigned char space[MAX_MESSAGE_SIZE];
};

static boolean_t do_server_thing(struct DummyMsg_t *requestMsg, struct DummyMsg_t *replyMsg) {
    mig_reply_error_t * request = (mig_reply_error_t *)requestMsg;
    mig_reply_error_t *	reply = (mig_reply_error_t *)replyMsg;
    mach_msg_return_t r = MACH_MSG_SUCCESS;
    mach_msg_options_t options = 0;

    boolean_t handled = HexFiendHelper_server((mach_msg_header_t *)request, (mach_msg_header_t *)reply);
    fprintf(ERR_FILE, "Got back %d\n", handled);
    if (handled) {
    /* Copied from Libc/mach/mach_msg.c:mach_msg_server_once(): Start */
        if (!(reply->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX)) {
            if (reply->RetCode == MIG_NO_REPLY)
                reply->Head.msgh_remote_port = MACH_PORT_NULL;
            else if ((reply->RetCode != KERN_SUCCESS) &&
                     (request->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX)) {
                /* destroy the request - but not the reply port */
                request->Head.msgh_remote_port = MACH_PORT_NULL;
                mach_msg_destroy(&request->Head);
            }
        }
        /*
         *	We don't want to block indefinitely because the client
         *	isn't receiving messages from the reply port.
         *	If we have a send-once right for the reply port, then
         *	this isn't a concern because the send won't block.
         *	If we have a send right, we need to use MACH_SEND_TIMEOUT.
         *	To avoid falling off the kernel's fast RPC path unnecessarily,
         *	we only supply MACH_SEND_TIMEOUT when absolutely necessary.
         */
        if (reply->Head.msgh_remote_port != MACH_PORT_NULL) {
            r = mach_msg(&reply->Head,
                         (MACH_MSGH_BITS_REMOTE(reply->Head.msgh_bits) ==
                          MACH_MSG_TYPE_MOVE_SEND_ONCE) ?
                         MACH_SEND_MSG|options :
                         MACH_SEND_MSG|MACH_SEND_TIMEOUT|options,
                         reply->Head.msgh_size, 0, MACH_PORT_NULL,
                         MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
            if ((r != MACH_SEND_INVALID_DEST) &&
                (r != MACH_SEND_TIMED_OUT))
                goto done_once;
        }
        if (reply->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX)
            mach_msg_destroy(&reply->Head);
     done_once:
        /* Copied from Libc/mach/mach_msg.c:mach_msg_server_once(): End */
        ;
    }
    return handled;
    
}

static void run_server(mach_port_t portset, mach_port_t notification_port) {
    struct DummyMsg_t DumMsg, DumMsgReply;
    int isFinished = 0;
    while (! isFinished) {
        bzero(&DumMsg, sizeof DumMsg);
        bzero(&DumMsgReply, sizeof DumMsgReply);
        DumMsg.head.msgh_size = sizeof DumMsg;
        DumMsg.head.msgh_local_port = portset;
        mach_msg_return_t msgcode = mach_msg(&DumMsg.head, MACH_RCV_MSG, 0, sizeof DumMsg, portset, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        if (msgcode != MACH_MSG_SUCCESS) {
            fprintf(ERR_FILE, "error %s in Receive, message will be ignored.\n", mach_error_string((kern_return_t)msgcode));
        }
        else {
            /* Try handling it from the server */
            boolean_t handled = do_server_thing(&DumMsg, &DumMsgReply);
            if (! handled) {
                /* Could be a No Senders notification */
                if (DumMsg.head.msgh_id == MACH_NOTIFY_NO_SENDERS) {
                    /* Our parent process died, or closed our port, so we should go away */
                    isFinished = 1;
                }
                else {
                    fprintf(ERR_FILE, "Unknown Mach message id %ld\n", (long)DumMsg.head.msgh_id);
                }
            }
        }
        fflush(ERR_FILE);
    }
}

int main(void) {
   // close_all_open_files();
    puts("get_parent_receive_port");
    mach_port_t parent_recv_port = get_parent_receive_port();
    puts("Done");
    
    mach_port_t my_task = mach_task_self();
    
    mach_port_t notificationPort = MACH_PORT_NULL;
    CHECK_MACH_ERROR(mach_port_allocate(my_task, MACH_PORT_RIGHT_RECEIVE, &notificationPort));
    mach_port_t old;
    CHECK_MACH_ERROR(mach_port_request_notification(my_task, parent_recv_port, MACH_NOTIFY_NO_SENDERS, 0/*sync*/, notificationPort, MACH_MSG_TYPE_MAKE_SEND_ONCE, &old));
    
    /* Make a port set */
    mach_port_t portSet = MACH_PORT_NULL;
    CHECK_MACH_ERROR(mach_port_allocate(my_task, MACH_PORT_RIGHT_PORT_SET, &portSet));
    CHECK_MACH_ERROR(mach_port_insert_member(my_task, parent_recv_port, portSet));
    CHECK_MACH_ERROR(mach_port_insert_member(my_task, notificationPort, portSet));
    ERR_FILE = fopen("/tmp/FortunateSonErrorFile.txt", "a");
    run_server(portSet, notificationPort);
    return 0;
}

}
