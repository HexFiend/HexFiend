#include <stdio.h>
#include <stdlib.h>
#include <mach/mach.h>

/* Credit to Michael Weber for the following code */

#define CHECK_MACH_ERROR(a, b) do { if ((a) != KERN_SUCCESS) { printf("Mach error %x on line %d: %s\n", (a), __LINE__, (b));  if (0) *(int *)NULL = 0; } } while (0)


static int setup_recv_port (mach_port_t *recv_port) {
    kern_return_t       err;
    mach_port_t         port = MACH_PORT_NULL;
    err = mach_port_allocate (mach_task_self (),
                              MACH_PORT_RIGHT_RECEIVE, &port);
    CHECK_MACH_ERROR (err, "mach_port_allocate failed:");

    err = mach_port_insert_right (mach_task_self (),
                                  port,
                                  port,
                                  MACH_MSG_TYPE_MAKE_SEND);
    CHECK_MACH_ERROR (err, "mach_port_insert_right failed:");

    *recv_port = port;
    return 0;
}

static int
send_port (mach_port_t remote_port, mach_port_t port)
{
    kern_return_t       err;

    struct {
        mach_msg_header_t          header;
        mach_msg_body_t            body;
        mach_msg_port_descriptor_t task_port;
    } msg;

    msg.header.msgh_remote_port = remote_port;
    msg.header.msgh_local_port = MACH_PORT_NULL;
    msg.header.msgh_bits = MACH_MSGH_BITS (MACH_MSG_TYPE_COPY_SEND, 0) |
        MACH_MSGH_BITS_COMPLEX;
    msg.header.msgh_size = sizeof msg;

    msg.body.msgh_descriptor_count = 1;
    msg.task_port.name = port;
    msg.task_port.disposition = MACH_MSG_TYPE_COPY_SEND;
    msg.task_port.type = MACH_MSG_PORT_DESCRIPTOR;

    printf("%d SENDING SIZE %u\n", getpid(), msg.header.msgh_size);

    err = mach_msg_send (&msg.header);
    CHECK_MACH_ERROR (err, "mach_msg_send failed:");

    return 0;
}

static int
recv_port (mach_port_t recv_port, mach_port_t *port)
{
    kern_return_t       err;
    struct {
        mach_msg_header_t          header;
        mach_msg_body_t            body;
        mach_msg_port_descriptor_t task_port;
        mach_msg_trailer_t         trailer;
	char			   bufferToShutUpXcode[160];
    } msg = {0};

    /* When we fork(), Xcode sends us some crap on our bootstrap port.  Ignore it.  I think this only happens when running in Xcode in the debugger. */
    while (1) {
	err = mach_msg (&msg.header, MACH_RCV_MSG | MACH_RCV_LARGE,
			0, sizeof msg, recv_port,
			MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
	CHECK_MACH_ERROR (err, "mach_msg failed:");
	if (msg.header.msgh_size == 172) {
	    /* Xcode crap, just loop */
	}
	else {
	    break;
	}
    }

    *port = msg.task_port.name;
    return 0;
}

