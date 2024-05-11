#include "userprog/process.h"
#include <debug.h>
#include <inttypes.h>
#include <round.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <threads/malloc.h>
#include "userprog/gdt.h"
#include "userprog/pagedir.h"
#include "userprog/tss.h"
#include "filesys/directory.h"
#include "filesys/file.h"
#include "filesys/filesys.h"
#include "threads/flags.h"
#include "threads/init.h"
#include "threads/interrupt.h"
#include "threads/palloc.h"
#include "threads/thread.h"
#include "threads/vaddr.h"

static thread_func start_process NO_RETURN;
static bool load (const char *cmdline, void (**eip) (void), void **esp);
void push_argument (void **esp, int argc, int argv[]);


tid_t
process_execute (const char *file_name)
{
  tid_t tid;

  char *fn_copy = malloc(strlen(file_name)+1);
  char *fn_copy2 = malloc(strlen(file_name)+1);
  strlcpy (fn_copy, file_name, strlen(file_name)+1);
  strlcpy (fn_copy2, file_name, strlen(file_name)+1);


  char * save_ptr;
  fn_copy2 = strtok_r (fn_copy2, " ", &save_ptr);
  tid = thread_create (fn_copy2, PRI_DEFAULT, start_process, fn_copy);
  free (fn_copy2);

  if (tid == TID_ERROR){
    free (fn_copy);
    return tid;
  }

  sema_down(&thread_current()->sema);
  if (!thread_current()->success) return TID_ERROR;

  return tid;
}

void
push_argument (void **esp, int argc, int argv[]){
  *esp = (int)*esp & 0xfffffffc;
  *esp -= 4;
  *(int *) *esp = 0;
  for (int i = argc - 1; i >= 0; i--)
  {
    *esp -= 4;
    *(int *) *esp = argv[i];
  }
  *esp -= 4;
  *(int *) *esp = (int) *esp + 4;
  *esp -= 4;
  *(int *) *esp = argc;
  *esp -= 4;
  *(int *) *esp = 0;
}



static void
start_process (void *file_name_)
{
  char *file_name = file_name_;
  struct intr_frame if_;
  bool success;

  char *fn_copy=malloc(strlen(file_name)+1);
  strlcpy(fn_copy,file_name,strlen(file_name)+1);

 
  memset (&if_, 0, sizeof if_);
  if_.gs = if_.fs = if_.es = if_.ds = if_.ss = SEL_UDSEG;
  if_.cs = SEL_UCSEG;
  if_.eflags = FLAG_IF | FLAG_MBS;

  char *token, *save_ptr;
  file_name = strtok_r (file_name, " ", &save_ptr);
  success = load (file_name, &if_.eip, &if_.esp);

  if (success){
 
    int argc = 0;
 
    int argv[50];
    for (token = strtok_r (fn_copy, " ", &save_ptr); token != NULL; token = strtok_r (NULL, " ", &save_ptr)){
      if_.esp -= (strlen(token)+1);
      memcpy (if_.esp, token, strlen(token)+1);
      argv[argc++] = (int) if_.esp;
    }
    push_argument (&if_.esp, argc, argv);
    thread_current ()->parent->success = true;
    sema_up (&thread_current ()->parent->sema);
  }

  else{
    thread_current ()->parent->success = false;
    sema_up (&thread_current ()->parent->sema);
    thread_exit ();
  }


  asm volatile ("movl %0, %%esp; jmp intr_exit" : : "g" (&if_) : "memory");
  NOT_REACHED ();
}




int
process_wait (tid_t child_tid UNUSED)
{
  struct list *l = &thread_current()->childs;
  struct list_elem *temp;
  temp = list_begin (l);
  struct child *temp2 = NULL;
  while (temp != list_end (l))
  {
    temp2 = list_entry (temp, struct child, child_elem);
    if (temp2->tid == child_tid)
    {
      if (!temp2->isrun)
      {
        temp2->isrun = true;
        sema_down (&temp2->sema);
        break;
      } 
      else 
      {
        return -1;
      }
    }
    temp = list_next (temp);
  }
  if (temp == list_end (l)) {
    return -1;
  }
  list_remove (temp);
  return temp2->store_exit;
}

void
process_exit (void)
{
  struct thread *cur = thread_current ();
  uint32_t *pd;


  pd = cur->pagedir;
  if (pd != NULL)
  {

    cur->pagedir = NULL;
    pagedir_activate (NULL);
    pagedir_destroy (pd);
  }
}


void
process_activate (void)
{
  struct thread *t = thread_current ();

  pagedir_activate (t->pagedir);


  tss_update ();
}


typedef uint32_t Elf32_Word, Elf32_Addr, Elf32_Off;
typedef uint16_t Elf32_Half;

#define PE32Wx PRIx32   
#define PE32Ax PRIx32   
#define PE32Ox PRIx32   
#define PE32Hx PRIx16  


struct Elf32_Ehdr
  {
    unsigned char e_ident[16];
    Elf32_Half    e_type;
    Elf32_Half    e_machine;
    Elf32_Word    e_version;
    Elf32_Addr    e_entry;
    Elf32_Off     e_phoff;
    Elf32_Off     e_shoff;
    Elf32_Word    e_flags;
    Elf32_Half    e_ehsize;
    Elf32_Half    e_phentsize;
    Elf32_Half    e_phnum;
    Elf32_Half    e_shentsize;
    Elf32_Half    e_shnum;
    Elf32_Half    e_shstrndx;
  };


struct Elf32_Phdr
  {
    Elf32_Word p_type;
    Elf32_Off  p_offset;
    Elf32_Addr p_vaddr;
    Elf32_Addr p_paddr;
    Elf32_Word p_filesz;
    Elf32_Word p_memsz;
    Elf32_Word p_flags;
    Elf32_Word p_align;
  };

#define PT_NULL    0            
#define PT_LOAD    1            
#define PT_DYNAMIC 2            
#define PT_INTERP  3            
#define PT_NOTE    4            
#define PT_SHLIB   5            
#define PT_PHDR    6           
#define PT_STACK   0x6474e551   

#define PF_X 1          
#define PF_W 2          
#define PF_R 4          

static bool setup_stack (void **esp);
static bool validate_segment (const struct Elf32_Phdr *, struct file *);
static bool load_segment (struct file *file, off_t ofs, uint8_t *upage,
                          uint32_t read_bytes, uint32_t zero_bytes,
                          bool writable);


bool
load (const char *file_name, void (**eip) (void), void **esp)
{
  struct thread *t = thread_current ();
  struct Elf32_Ehdr ehdr;
  struct file *file = NULL;
  off_t file_ofs;
  bool success = false;
  int i;

  t->pagedir = pagedir_create ();
  if (t->pagedir == NULL)
    goto done;
  process_activate ();

  acquire_lock_f ();
  file = filesys_open (file_name);
  if (file == NULL)
  {
    printf ("load: %s: open failed\n", file_name);
    goto done;
  }
  file_deny_write(file);
  t->file_owned = file;
  if (file_read (file, &ehdr, sizeof ehdr) != sizeof ehdr
      || memcmp (ehdr.e_ident, "\177ELF\1\1\1", 7)
      || ehdr.e_type != 2
      || ehdr.e_machine != 3
      || ehdr.e_version != 1
      || ehdr.e_phentsize != sizeof (struct Elf32_Phdr)
      || ehdr.e_phnum > 1024)
    {
      printf ("load: %s: error loading executable\n", file_name);
      goto done;
    }

  file_ofs = ehdr.e_phoff;
  for (i = 0; i < ehdr.e_phnum; i++)
    {
      struct Elf32_Phdr phdr;

      if (file_ofs < 0 || file_ofs > file_length (file))
        goto done;
      file_seek (file, file_ofs);

      if (file_read (file, &phdr, sizeof phdr) != sizeof phdr)
        goto done;
      file_ofs += sizeof phdr;
      switch (phdr.p_type)
        {
        case PT_NULL:
        case PT_NOTE:
        case PT_PHDR:
        case PT_STACK:
        default:
          break;
        case PT_DYNAMIC:
        case PT_INTERP:
        case PT_SHLIB:
          goto done;
        case PT_LOAD:
          if (validate_segment (&phdr, file))
            {
              bool writable = (phdr.p_flags & PF_W) != 0;
              uint32_t file_page = phdr.p_offset & ~PGMASK;
              uint32_t mem_page = phdr.p_vaddr & ~PGMASK;
              uint32_t page_offset = phdr.p_vaddr & PGMASK;
              uint32_t read_bytes, zero_bytes;
              if (phdr.p_filesz > 0)
                {
                  
                  read_bytes = page_offset + phdr.p_filesz;
                  zero_bytes = (ROUND_UP (page_offset + phdr.p_memsz, PGSIZE)
                                - read_bytes);
                }
              else
                {
                
                  read_bytes = 0;
                  zero_bytes = ROUND_UP (page_offset + phdr.p_memsz, PGSIZE);
                }
              if (!load_segment (file, file_page, (void *) mem_page,
                                 read_bytes, zero_bytes, writable))
                goto done;
            }
          else
            goto done;
          break;
        }
    }


  if (!setup_stack (esp))
    goto done;

  *eip = (void (*) (void)) ehdr.e_entry;

  success = true;

 done:
  release_lock_f();
  return success;
}


static bool install_page (void *upage, void *kpage, bool writable);


static bool
validate_segment (const struct Elf32_Phdr *phdr, struct file *file)
{
  if ((phdr->p_offset & PGMASK) != (phdr->p_vaddr & PGMASK))
    return false;

  if (phdr->p_offset > (Elf32_Off) file_length (file))
    return false;

  if (phdr->p_memsz < phdr->p_filesz)
    return false;

  if (phdr->p_memsz == 0)
    return false;


  if (!is_user_vaddr ((void *) phdr->p_vaddr))
    return false;
  if (!is_user_vaddr ((void *) (phdr->p_vaddr + phdr->p_memsz)))
    return false;


  if (phdr->p_vaddr + phdr->p_memsz < phdr->p_vaddr)
    return false;


  if (phdr->p_vaddr < PGSIZE)
    return false;

  return true;
}


static bool
load_segment (struct file *file, off_t ofs, uint8_t *upage,
              uint32_t read_bytes, uint32_t zero_bytes, bool writable)
{
  ASSERT ((read_bytes + zero_bytes) % PGSIZE == 0);
  ASSERT (pg_ofs (upage) == 0);
  ASSERT (ofs % PGSIZE == 0);

  file_seek (file, ofs);
  while (read_bytes > 0 || zero_bytes > 0)
    {

      size_t page_read_bytes = read_bytes < PGSIZE ? read_bytes : PGSIZE;
      size_t page_zero_bytes = PGSIZE - page_read_bytes;

      uint8_t *kpage = palloc_get_page (PAL_USER);
      if (kpage == NULL)
        return false;

      if (file_read (file, kpage, page_read_bytes) != (int) page_read_bytes)
        {
          palloc_free_page (kpage);
          return false;
        }
      memset (kpage + page_read_bytes, 0, page_zero_bytes);

      if (!install_page (upage, kpage, writable))
        {
          palloc_free_page (kpage);
          return false;
        }

      read_bytes -= page_read_bytes;
      zero_bytes -= page_zero_bytes;
      upage += PGSIZE;
    }
  return true;
}


static bool
setup_stack (void **esp)
{
  uint8_t *kpage;
  bool success = false;

  kpage = palloc_get_page (PAL_USER | PAL_ZERO);
  if (kpage != NULL)
    {
      success = install_page (((uint8_t *) PHYS_BASE) - PGSIZE, kpage, true);
      if (success)
        *esp = PHYS_BASE;
      else
        palloc_free_page (kpage);
    }
  return success;
}


static bool
install_page (void *upage, void *kpage, bool writable)
{
  struct thread *t = thread_current ();


  return (pagedir_get_page (t->pagedir, upage) == NULL
          && pagedir_set_page (t->pagedir, upage, kpage, writable));
}
