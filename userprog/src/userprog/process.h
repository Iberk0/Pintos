#ifndef USERPROG_PROCESS_H
#define USERPROG_PROCESS_H

#include "threads/thread.h"

void process_exit (void);
void process_activate (void);
tid_t process_execute (const char *file_name);
int process_wait (tid_t);


#endif /* userprog/process.h */
