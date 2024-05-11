
loader.out:     file format elf32-i386


Disassembly of section .text:

00007c00 <read_mbr-0x1c>:

# Set up segment registers.
# Set stack to grow downward from 60 kB (after boot, the kernel
# continues to use this stack for its initial thread).

	sub %ax, %ax
    7c00:	29 c0                	sub    %eax,%eax
	mov %ax, %ds
    7c02:	8e d8                	mov    %eax,%ds
	mov %ax, %ss
    7c04:	8e d0                	mov    %eax,%ss
	mov $0xf000, %esp
    7c06:	66 bc 00 f0          	mov    $0xf000,%sp
    7c0a:	00 00                	add    %al,(%eax)

# Configure serial port so we can report progress without connected VGA.
# See [IntrList] for details.
	sub %dx, %dx			# Serial port 0.
    7c0c:	29 d2                	sub    %edx,%edx
	mov $0xe3, %al			# 9600 bps, N-8-1.
    7c0e:	b0 e3                	mov    $0xe3,%al
					# AH is already 0 (Initialize Port).
	int $0x14			# Destroys AX.
    7c10:	cd 14                	int    $0x14

	call puts
    7c12:	e8 d0 00 50 69       	call   69507ce7 <__bss_start+0x694ffee7>
    7c17:	4c                   	dec    %esp
    7c18:	6f                   	outsl  %ds:(%esi),(%dx)
    7c19:	00                   	.byte 0x0
####
#### We print out status messages to show the disk and partition being
#### scanned, e.g. hda1234 as we scan four partitions on the first
#### hard disk.

	mov $0x80, %dl			# Hard disk 0.
    7c1a:	b2 80                	mov    $0x80,%dl

00007c1c <read_mbr>:
read_mbr:
	sub %ebx, %ebx			# Sector 0.
    7c1c:	66 29 db             	sub    %bx,%bx
	mov $0x2000, %ax		# Use 0x20000 for buffer.
    7c1f:	b8 00 20 8e c0       	mov    $0xc08e2000,%eax
	mov %ax, %es
	call read_sector
    7c24:	e8 f6 00 72 42       	call   42727d1f <__bss_start+0x4271ff1f>
	jc no_such_drive

	# Print hd[a-z].
	call puts
    7c29:	e8 b9 00 20 68       	call   68207ce7 <__bss_start+0x681ffee7>
    7c2e:	64 00 88 d0 04 e1 e8 	add    %cl,%fs:-0x171efb30(%eax)
	.string " hd"
	mov %dl, %al
	add $'a' - 0x80, %al
	call putc
    7c35:	c6 00 26             	movb   $0x26,(%eax)

	# Check for MBR signature--if not present, it's not a
	# partitioned hard disk.
	cmpw $0xaa55, %es:510
    7c38:	81 3e fe 01 55 aa    	cmpl   $0xaa5501fe,(%esi)
	jne next_drive
    7c3e:	75 27                	jne    7c67 <next_drive>

	mov $446, %si			# Offset of partition table entry 1.
    7c40:	be be 01 b0 31       	mov    $0x31b001be,%esi

00007c45 <check_partition>:
	mov $'1', %al
check_partition:
	# Is it an unused partition?
	cmpl $0, %es:(%si)
    7c45:	26 66 83 3c 00 74    	cmpw   $0x74,%es:(%eax,%eax,1)
	je next_partition
    7c4b:	10 e8                	adc    %ch,%al

	# Print [1-4].
	call putc
    7c4d:	ae                   	scas   %es:(%edi),%al
    7c4e:	00 26                	add    %ah,(%esi)

	# Is it a Pintos kernel partition?
	cmpb $0x20, %es:4(%si)
    7c50:	80 7c 04 20 75       	cmpb   $0x75,0x20(%esp,%eax,1)
	jne next_partition
    7c55:	06                   	push   %es

	# Is it a bootable partition?
	cmpb $0x80, %es:(%si)
    7c56:	26 80 3c 80 74       	cmpb   $0x74,%es:(%eax,%eax,4)
	je load_kernel
    7c5b:	20                   	.byte 0x20

00007c5c <next_partition>:

next_partition:
	# No match for this partition, go on to the next one.
	add $16, %si			# Offset to next partition table entry.
    7c5c:	83 c6 10             	add    $0x10,%esi
	inc %al
    7c5f:	fe c0                	inc    %al
	cmp $510, %si
    7c61:	81 fe fe 01 72 de    	cmp    $0xde7201fe,%esi

00007c67 <next_drive>:
	jb check_partition

next_drive:
	# No match on this drive, go on to the next one.
	inc %dl
    7c67:	fe c2                	inc    %dl
	jnc read_mbr
    7c69:	73 b1                	jae    7c1c <read_mbr>

00007c6b <no_boot_partition>:

no_such_drive:
no_boot_partition:
	# Didn't find a Pintos kernel partition anywhere, give up.
	call puts
    7c6b:	e8 77 00 0d 4e       	call   4e0d7ce7 <__bss_start+0x4e0cfee7>
    7c70:	6f                   	outsl  %ds:(%esi),(%dx)
    7c71:	74 20                	je     7c93 <load_kernel+0x17>
    7c73:	66 6f                	outsw  %ds:(%esi),(%dx)
    7c75:	75 6e                	jne    7ce5 <puts>
    7c77:	64                   	fs
    7c78:	0d                   	.byte 0xd
    7c79:	00 cd                	add    %cl,%ch
	.string "\rNot found\r"

	# Notify BIOS that boot failed.  See [IntrList].
	int $0x18
    7c7b:	18                   	.byte 0x18

00007c7c <load_kernel>:
#### We found a kernel.  The kernel's drive is in DL.  The partition
#### table entry for the kernel's partition is at ES:SI.  Our job now
#### is to read the kernel from disk and jump to its start address.

load_kernel:
	call puts
    7c7c:	e8 66 00 0d 4c       	call   4c0d7ce7 <__bss_start+0x4c0cfee7>
    7c81:	6f                   	outsl  %ds:(%esi),(%dx)
    7c82:	61                   	popa   
    7c83:	64 69 6e 67 00 26 66 	imul   $0x8b662600,%fs:0x67(%esi),%ebp
    7c8a:	8b 
	# just an ELF format object, which doesn't have an
	# easy-to-read field to identify its own size (see [ELF1]).
	# But we limit Pintos kernels to 512 kB for other reasons, so
	# it's easy enough to just read the entire contents of the
	# partition or 512 kB from disk, whichever is smaller.
	mov %es:12(%si), %ecx		# EBP = number of sectors
    7c8b:	4c                   	dec    %esp
    7c8c:	0c 66                	or     $0x66,%al
	cmp $1024, %ecx			# Cap size at 512 kB
    7c8e:	81 f9 00 04 00 00    	cmp    $0x400,%ecx
	jbe 1f
    7c94:	76 03                	jbe    7c99 <load_kernel+0x1d>
	mov $1024, %cx
    7c96:	b9 00 04 26 66       	mov    $0x66260400,%ecx
1:

	mov %es:8(%si), %ebx		# EBX = first sector
    7c9b:	8b 5c 08 b8          	mov    -0x48(%eax,%ecx,1),%ebx
	mov $0x2000, %ax		# Start load address: 0x20000
    7c9f:	00 20                	add    %ah,(%eax)

00007ca1 <next_sector>:

next_sector:
	# Read one sector into memory.
	mov %ax, %es			# ES:0000 -> load address
    7ca1:	8e c0                	mov    %eax,%es
	call read_sector
    7ca3:	e8 77 00 72 2d       	call   2d727d1f <__bss_start+0x2d71ff1f>
	jc read_failed

	# Print '.' as progress indicator once every 16 sectors == 8 kB.
	test $15, %bl
    7ca8:	f6 c3 0f             	test   $0xf,%bl
	jnz 1f
    7cab:	75 05                	jne    7cb2 <next_sector+0x11>
	call puts
    7cad:	e8 35 00 2e 00       	call   2e7ce7 <__bss_start+0x2dfee7>
	.string "."
1:

	# Advance memory pointer and disk sector.
	add $0x20, %ax
    7cb2:	83 c0 20             	add    $0x20,%eax
	inc %bx
    7cb5:	43                   	inc    %ebx
	loop next_sector
    7cb6:	e2 e9                	loop   7ca1 <next_sector>

	call puts
    7cb8:	e8 2a 00 0d 00       	call   d7ce7 <__bss_start+0xcfee7>
#### registers, so in fact we store the address in a temporary memory
#### location, then jump indirectly through that location.  To save 4
#### bytes in the loader, we reuse 4 bytes of the loader's code for
#### this temporary pointer.

	mov $0x2000, %ax
    7cbd:	b8 00 20 8e c0       	mov    $0xc08e2000,%eax
	mov %ax, %es
	mov %es:0x18, %dx
    7cc2:	26 8b 16             	mov    %es:(%esi),%edx
    7cc5:	18 00                	sbb    %al,(%eax)
	mov %dx, start
    7cc7:	89 16                	mov    %edx,(%esi)
    7cc9:	d5 7c                	aad    $0x7c
	movw $0x2000, start + 2
    7ccb:	c7 06 d7 7c 00 20    	movl   $0x20007cd7,(%esi)
	ljmp *start
    7cd1:	ff 2e                	ljmp   *(%esi)
    7cd3:	d5 7c                	aad    $0x7c

00007cd5 <read_failed>:

read_failed:
start:
	# Disk sector read failed.
	call puts
    7cd5:	e8 0d 00 0d 42       	call   420d7ce7 <__bss_start+0x420cfee7>
    7cda:	61                   	popa   
    7cdb:	64 20 72 65          	and    %dh,%fs:0x65(%edx)
    7cdf:	61                   	popa   
    7ce0:	64                   	fs
    7ce1:	0d                   	.byte 0xd
    7ce2:	00 cd                	add    %cl,%ch
1:	.string "\rBad read\r"

	# Notify BIOS that boot failed.  See [IntrList].
	int $0x18
    7ce4:	18                   	.byte 0x18

00007ce5 <puts>:
#### subroutine takes its null-terminated string argument from the
#### code stream just after the call, and then returns to the byte
#### just after the terminating null.  This subroutine preserves all
#### general-purpose registers.

puts:	xchg %si, %ss:(%esp)
    7ce5:	67 87 34             	xchg   %esi,(%si)
    7ce8:	24 50                	and    $0x50,%al

00007cea <next_char>:
	push %ax
next_char:
	mov %cs:(%si), %al
    7cea:	2e 8a 04 46          	mov    %cs:(%esi,%eax,2),%al
	inc %si
	test %al, %al
    7cee:	84 c0                	test   %al,%al
	jz 1f
    7cf0:	74 05                	je     7cf7 <next_char+0xd>
	call putc
    7cf2:	e8 08 00 eb f3       	call   f3eb7cff <__bss_start+0xf3eafeff>
	jmp next_char
1:	pop %ax
    7cf7:	58                   	pop    %eax
	xchg %si, %ss:(%esp)
    7cf8:	67 87 34             	xchg   %esi,(%si)
    7cfb:	24 c3                	and    $0xc3,%al

00007cfd <putc>:
#### [IntrList]).  Preserves all general-purpose registers.
####
#### If called upon to output a carriage return, this subroutine
#### automatically supplies the following line feed.

putc:	pusha
    7cfd:	60                   	pusha  

1:	sub %bh, %bh			# Page 0.
    7cfe:	28 ff                	sub    %bh,%bh
	mov $0x0e, %ah			# Teletype output service.
    7d00:	b4 0e                	mov    $0xe,%ah
	int $0x10
    7d02:	cd 10                	int    $0x10

	mov $0x01, %ah			# Serial port output service.
    7d04:	b4 01                	mov    $0x1,%ah
	sub %dx, %dx			# Serial port 0.
    7d06:	29 d2                	sub    %edx,%edx
2:	int $0x14			# Destroys AH.
    7d08:	cd 14                	int    $0x14
	test $0x80, %ah			# Output timed out?
    7d0a:	f6 c4 80             	test   $0x80,%ah
	jz 3f
    7d0d:	74 06                	je     7d15 <putc+0x18>
	movw $0x9090, 2b		# Turn "int $0x14" above into NOPs.
    7d0f:	c7 06 08 7d 90 90    	movl   $0x90907d08,(%esi)

3:
	cmp $'\r', %al
    7d15:	3c 0d                	cmp    $0xd,%al
	jne popa_ret
    7d17:	75 18                	jne    7d31 <popa_ret>
	mov $'\n', %al
    7d19:	b0 0a                	mov    $0xa,%al
	jmp 1b
    7d1b:	eb e1                	jmp    7cfe <putc+0x1>

00007d1d <read_sector>:
#### reads the specified sector into memory at ES:0000.  Returns with
#### carry set on error, clear otherwise.  Preserves all
#### general-purpose registers.

read_sector:
	pusha
    7d1d:	60                   	pusha  
	sub %ax, %ax
    7d1e:	29 c0                	sub    %eax,%eax
	push %ax			# LBA sector number [48:63]
    7d20:	50                   	push   %eax
	push %ax			# LBA sector number [32:47]
    7d21:	50                   	push   %eax
	push %ebx			# LBA sector number [0:31]
    7d22:	66 53                	push   %bx
	push %es			# Buffer segment
    7d24:	06                   	push   %es
	push %ax			# Buffer offset (always 0)
    7d25:	50                   	push   %eax
	push $1				# Number of sectors to read
    7d26:	6a 01                	push   $0x1
	push $16			# Packet size
    7d28:	6a 10                	push   $0x10
	mov $0x42, %ah			# Extended read
    7d2a:	b4 42                	mov    $0x42,%ah
	mov %sp, %si			# DS:SI -> packet
    7d2c:	89 e6                	mov    %esp,%esi
	int $0x13			# Error code in CF
    7d2e:	cd 13                	int    $0x13
	popa				# Pop 16 bytes, preserve flags
    7d30:	61                   	popa   

00007d31 <popa_ret>:
popa_ret:
	popa
    7d31:	61                   	popa   
	ret				# Error code still in CF
    7d32:	c3                   	ret    
	...
    7dfb:	00 00                	add    %al,(%eax)
    7dfd:	00 55 aa             	add    %dl,-0x56(%ebp)
