#include "HFHelperProcessSharedCode.h"
#include <asl.h>
#include <unistd.h>
#include <launch.h>
#include <errno.h>

extern "C" {
#include "FortunateSonServer.h"
}

#define MAX_MESSAGE_SIZE 512

static FILE *ERR_FILE;

struct DummyMsg_t {
    mach_msg_header_t head;
    mach_msg_body_t body;
    unsigned char space[MAX_MESSAGE_SIZE];
};

static boolean_t handle_server_message(struct DummyMsg_t *requestMsg, struct DummyMsg_t *replyMsg) {
    mig_reply_error_t * request = (mig_reply_error_t *)requestMsg;
    mig_reply_error_t *	reply = (mig_reply_error_t *)replyMsg;
    mach_msg_return_t r = MACH_MSG_SUCCESS;
    mach_msg_options_t options = 0;

    boolean_t handled = HexFiendHelper_server((mach_msg_header_t *)request, (mach_msg_header_t *)reply);
    //if (ERR_FILE) fprintf(ERR_FILE, "Got back %d\n", handled);
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
    (void)notification_port;
    struct DummyMsg_t DumMsg, DumMsgReply;
    int isFinished = 0;
    while (! isFinished) {
        bzero(&DumMsg, sizeof DumMsg);
        bzero(&DumMsgReply, sizeof DumMsgReply);
        DumMsg.head.msgh_size = sizeof DumMsg;
        DumMsg.head.msgh_local_port = portset;
        mach_msg_return_t msgcode = mach_msg(&DumMsg.head, MACH_RCV_MSG, 0, sizeof DumMsg, portset, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        if (msgcode != MACH_MSG_SUCCESS) {
            if (ERR_FILE) fprintf(ERR_FILE, "error %s in Receive, message will be ignored.\n", mach_error_string((kern_return_t)msgcode));
        }
        else {
            /* Try handling it from the server */
            boolean_t handled = handle_server_message(&DumMsg, &DumMsgReply);
            if (! handled) {
                /* Could be a No Senders notification */
                if (DumMsg.head.msgh_id == MACH_NOTIFY_NO_SENDERS) {
                    /* Our parent process died, or closed our port, so we should go away */
                    if (ERR_FILE) fprintf(ERR_FILE, "Parent appears to have closed its port, so we're exiting.\n");
                    isFinished = 1;
                }
                else {
                    if (ERR_FILE) fprintf(ERR_FILE, "Unknown Mach message id %ld\n", (long)DumMsg.head.msgh_id);
                }
            }
        }
        if (ERR_FILE) fflush(ERR_FILE);
    }
}

/* Get the Mach port upon which we'll receive requests from our parent */
static mach_port_t get_hex_fiend_receive_port(void) {
    mach_port_t launchdReceivePort = MACH_PORT_NULL, hexFiendReceivePort = MACH_PORT_NULL;
    launch_data_t resp = NULL, machServices = NULL, msg = NULL, service = NULL;
    int err = 0;
    
    /* Check in with launchd */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    msg = launch_data_new_string(LAUNCH_KEY_CHECKIN);
	resp = launch_msg(msg);
#pragma clang diagnostic pop
	if (resp == NULL) {
		if (ERR_FILE) fprintf(ERR_FILE, "launch_msg(): %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}
    
    /* Guard against errors */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	if (launch_data_get_type(resp) == LAUNCH_DATA_ERRNO) {
		errno = launch_data_get_errno(resp);
#pragma clang diagnostic pop
		if (ERR_FILE) fprintf(ERR_FILE, "launch_msg() response: %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}
    
    /* Get our MachServices dictioanry */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	machServices = launch_data_dict_lookup(resp, LAUNCH_JOBKEY_MACHSERVICES);
#pragma clang diagnostic pop
    
    /* Die if it's not there */
	if (machServices == NULL) {
		if (ERR_FILE) fprintf(ERR_FILE, "No mach services found!\n");
		exit(EXIT_FAILURE);
	}
    
    /* Get the one we care about */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    service = launch_data_dict_lookup(machServices, kPrivilegedHelperLaunchdLabel);
#pragma clang diagnostic pop
    if (service == NULL) {
		if (ERR_FILE) fprintf(ERR_FILE, "Mach service %s not found!\n", kPrivilegedHelperLaunchdLabel);
		exit(EXIT_FAILURE);
    }
    
    /* Make sure we've got a mach port */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (launch_data_get_type(service) != LAUNCH_DATA_MACHPORT) {
#pragma clang diagnostic pop
        if (ERR_FILE) fprintf(ERR_FILE, "%s: not a mach port\n", kPrivilegedHelperLaunchdLabel);
        exit(EXIT_FAILURE);
    }
    
    /* Now get the launchd mach port */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    launchdReceivePort = launch_data_get_machport(service);
#pragma clang diagnostic pop
    
    /* We don't want to use launchd's port - we want one from Hex Fiend (so we can get a no senders notification). So receive a port from Hex Fiend on our launchd port. */
    hexFiendReceivePort = MACH_PORT_NULL;
    if ((err = recv_port(launchdReceivePort, &hexFiendReceivePort))) {
        if (ERR_FILE) fprintf(ERR_FILE, "recv_port() failed with Mach error %d\n", err);
        exit(EXIT_FAILURE);
    }
    
    /* Make sure we got something back */
    if (hexFiendReceivePort == MACH_PORT_NULL) {
        if (ERR_FILE) fprintf(ERR_FILE, "recv_port() returned a null Mach port\n");
        exit(EXIT_FAILURE);
    }
    
    /* Clean up */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (msg) launch_data_free(msg);
    if (resp) launch_data_free(resp);
#pragma clang diagnostic pop
    
    return hexFiendReceivePort;
}


int main(void) {
    ERR_FILE = fopen("/tmp/FortunateSonErrorFile.txt", "a");
    fprintf(ERR_FILE, "Started with pid %d\n", getpid());
    
    mach_port_t parent_recv_port = get_hex_fiend_receive_port();
    
    // Get notified when the parent receive port dies
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
    run_server(portSet, notificationPort);
    
    /* Once run_server returns, we're done, so exit */
    return 0;
}
