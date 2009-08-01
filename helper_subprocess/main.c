#import "HFHelperProcessSharedCode.h"
#include <unistd.h>

/* I wish there were a better way to do this */
static void close_all_open_files(void) {
    long open_max = sysconf(_SC_OPEN_MAX);
    int fd;
    for (fd = 0; fd < open_max; fd++) {
	close(fd);
    }
}

static mach_port_t get_parent_receive_port(void) {
    kern_return_t err;
    const mach_port_t errorReturn = MACH_PORT_NULL;
    mach_port_t parent_recv_port = MACH_PORT_NULL;
    mach_port_t child_recv_port = MACH_PORT_NULL;
    err = task_get_bootstrap_port (mach_task_self (), &parent_recv_port);
    CHECK_MACH_ERROR (err, "task_get_bootstrap_port failed:");
    if (setup_recv_port (&child_recv_port) != 0)
	return errorReturn;
    if (send_port (parent_recv_port, mach_task_self ()) != 0)
	return errorReturn;
    if (send_port (parent_recv_port, child_recv_port) != 0)
	return errorReturn;
    if (recv_port (child_recv_port, &bootstrap_port) != 0)
	return errorReturn;
    err = task_set_bootstrap_port (mach_task_self (), bootstrap_port);
    CHECK_MACH_ERROR (err, "task_set_bootstrap_port failed:");
    return child_recv_port;
}

int main(void) {
    close_all_open_files();
    puts("see ya");
    mach_port_t parent_recv_port = get_parent_receive_port();
    
    return 0;
}
