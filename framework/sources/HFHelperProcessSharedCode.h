#include <stdio.h>
#include <stdlib.h>
#include <mach/mach.h>
#include <mach/message.h>
#include <servers/bootstrap.h>
#include <unistd.h>

/* Credit to Michael Weber for the following code */

#define CHECK_MACH_ERROR(a) do {kern_return_t rr = (a); if ((rr) != KERN_SUCCESS) { printf("Mach error %x (%s) on line %d of file %s\n", (rr), mach_error_string((rr)), __LINE__, __FILE__); abort(); } } while (0)

static inline void derive_ipc_name(char buff[256], pid_t pid) {
    snprintf(buff, 256, "com.ridiculous_fish.HexFiend.parent_%ld", (long)pid);
}

#define kPrivilegedHelperLaunchdLabel "com.ridiculousfish.HexFiend.PrivilegedHelper"

__attribute__((used)) static int
send_port (mach_port_t remote_port, mach_port_t port, mach_msg_type_name_t send_type)
{
    struct {
        mach_msg_header_t          header;
        mach_msg_body_t            body;
        mach_msg_port_descriptor_t task_port;
    } msg;

    msg.header.msgh_remote_port = remote_port;
    msg.header.msgh_local_port = MACH_PORT_NULL;
    msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) | MACH_MSGH_BITS_COMPLEX;
    msg.header.msgh_size = sizeof msg;

    msg.body.msgh_descriptor_count = 1;
    msg.task_port.name = port;
    msg.task_port.disposition = send_type;
    msg.task_port.type = MACH_MSG_PORT_DESCRIPTOR;
    CHECK_MACH_ERROR(mach_msg_send(&msg.header));
    return 0;
}

//kern_return_t bootstrap_register2(mach_port_t, name_t, mach_port_t, uint64_t);


__attribute__((used)) static int
recv_port (mach_port_t recv_port, mach_port_t *port)
{
    kern_return_t       err;
    struct {
        mach_msg_header_t          header;
        mach_msg_body_t            body;
        mach_msg_port_descriptor_t task_port;
        mach_msg_trailer_t         trailer;
    } msg;
    bzero(&msg, sizeof msg);
    
    err = mach_msg (&msg.header, MACH_RCV_MSG,
                    0, sizeof msg, recv_port,
                    MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    *port = msg.task_port.name;
    return err;
}
